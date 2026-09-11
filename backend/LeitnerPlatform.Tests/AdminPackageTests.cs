using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using LeitnerPlatform.API.Controllers.v1;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;

namespace LeitnerPlatform.Tests
{
    public class AdminPackageTests
    {
        private LeitnerDbContext GetDatabaseContext()
        {
            var options = new DbContextOptionsBuilder<LeitnerDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            var databaseContext = new LeitnerDbContext(options);
            databaseContext.Database.EnsureCreated();
            return databaseContext;
        }

        private AdminController CreateController(LeitnerDbContext db, Mock<IAuditLogService>? mockAudit = null)
        {
            var mockEventBus = new Mock<IEventBus>();
            var auditService = mockAudit ?? new Mock<IAuditLogService>();
            var mockLogger = new Mock<ILogger<AdminController>>();

            var controller = new AdminController(db, mockEventBus.Object, auditService.Object, mockLogger.Object);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, "admin_user"),
                new Claim(ClaimTypes.Role, "Admin")
            }, "mock"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            return controller;
        }

        [Fact]
        public async Task CreatePackage_WithValidCourses_ShouldCreateSuccessfullyAndLogAudit()
        {
            var db = GetDatabaseContext();
            var course1 = new Course { Id = Guid.NewGuid(), Title = "Course 1", Version = 1 };
            var course2 = new Course { Id = Guid.NewGuid(), Title = "Course 2", Version = 1 };
            await db.Courses.AddRangeAsync(course1, course2);
            await db.SaveChangesAsync();

            var mockAudit = new Mock<IAuditLogService>();
            var controller = CreateController(db, mockAudit);

            var input = new CreatePackageInput
            {
                Title = "Test Bundle",
                Description = "Bundle Description",
                Price = 150000,
                CourseIds = new List<Guid> { course1.Id, course2.Id }
            };

            var actionResult = await controller.CreatePackage(input);
            var okResult = Assert.IsType<OkObjectResult>(actionResult);

            var createdPackage = await db.CoursePackages.Include(p => p.Items).FirstOrDefaultAsync();
            Assert.NotNull(createdPackage);
            Assert.Equal("Test Bundle", createdPackage.Title);
            Assert.Equal(2, createdPackage.Items.Count);

            mockAudit.Verify(a => a.LogActionAsync(
                "admin_user",
                "CREATE_PACKAGE",
                It.Is<string>(s => s.Contains(createdPackage.Id.ToString())),
                null,
                It.Is<string>(s => s.Contains("Test Bundle") && s.Contains(course1.Id.ToString()))
            ), Times.Once);
        }

        [Fact]
        public async Task CreatePackage_WithNonExistentCourse_ShouldReturnBadRequest()
        {
            var db = GetDatabaseContext();
            var controller = CreateController(db);

            var nonExistentId = Guid.NewGuid();
            var input = new CreatePackageInput
            {
                Title = "Invalid Course Bundle",
                Price = 50000,
                CourseIds = new List<Guid> { nonExistentId }
            };

            var actionResult = await controller.CreatePackage(input);
            var badRequest = Assert.IsType<BadRequestObjectResult>(actionResult);
            Assert.Contains(nonExistentId.ToString(), badRequest.Value?.ToString());
        }

        [Fact]
        public async Task UpdatePackage_AddingAndKeepingCourses_ShouldNotThrowObjectCycleOrEFTrackingCollision()
        {
            var db = GetDatabaseContext();
            var course1 = new Course { Id = Guid.NewGuid(), Title = "intro-listening", Version = 1 };
            var course2 = new Course { Id = Guid.NewGuid(), Title = "intro-vocabulary", Version = 1 };
            var course3 = new Course { Id = Guid.NewGuid(), Title = "intro-grammar", Version = 1 };
            var course4 = new Course { Id = Guid.NewGuid(), Title = "Words You Need to Know 1100", Version = 1 };
            await db.Courses.AddRangeAsync(course1, course2, course3, course4);

            var package = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Interchange level intro(yellow book)",
                Description = "English intro bundle",
                Price = 200000,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = course1.Id, DisplayOrder = 0 });
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = course2.Id, DisplayOrder = 1 });
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = course3.Id, DisplayOrder = 2 });

            await db.CoursePackages.AddAsync(package);
            await db.SaveChangesAsync();

            var mockAudit = new Mock<IAuditLogService>();
            var controller = CreateController(db, mockAudit);

            // User scenario: keeping course1, course2, course3, AND adding course4 (ticking the 4th box)
            var updateInput = new UpdatePackageInput
            {
                Title = "Interchange level intro(yellow book) Updated",
                CourseIds = new List<Guid> { course1.Id, course2.Id, course3.Id, course4.Id }
            };

            var actionResult = await controller.UpdatePackage(package.Id, updateInput);
            var okResult = Assert.IsType<OkObjectResult>(actionResult);

            // Verify items in DB
            var updatedPackage = await db.CoursePackages.Include(p => p.Items).FirstOrDefaultAsync(p => p.Id == package.Id);
            Assert.NotNull(updatedPackage);
            Assert.Equal("Interchange level intro(yellow book) Updated", updatedPackage.Title);
            Assert.Equal(4, updatedPackage.Items.Count);
            Assert.Contains(updatedPackage.Items, i => i.CourseId == course4.Id);

            // Verify audit logging succeeded without throwing cycle errors
            mockAudit.Verify(a => a.LogActionAsync(
                "admin_user",
                "UPDATE_PACKAGE",
                $"Package:{package.Id}",
                It.Is<string>(s => s.Contains("Interchange level intro(yellow book)")),
                It.Is<string>(s => s.Contains("Interchange level intro(yellow book) Updated") && s.Contains(course4.Id.ToString()))
            ), Times.Once);
        }

        [Fact]
        public async Task UpdatePackage_RemovingACourse_ShouldProperlyRemoveCourseFromPackage()
        {
            var db = GetDatabaseContext();
            var course1 = new Course { Id = Guid.NewGuid(), Title = "Course 1", Version = 1 };
            var course2 = new Course { Id = Guid.NewGuid(), Title = "Course 2", Version = 1 };
            await db.Courses.AddRangeAsync(course1, course2);

            var package = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Bundle 2",
                CreatedAt = DateTime.UtcNow
            };
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = course1.Id, DisplayOrder = 0 });
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = course2.Id, DisplayOrder = 1 });

            await db.CoursePackages.AddAsync(package);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            // Remove course1, retain course2
            var updateInput = new UpdatePackageInput
            {
                CourseIds = new List<Guid> { course2.Id }
            };

            var actionResult = await controller.UpdatePackage(package.Id, updateInput);
            Assert.IsType<OkObjectResult>(actionResult);

            var updatedPackage = await db.CoursePackages.Include(p => p.Items).FirstOrDefaultAsync(p => p.Id == package.Id);
            Assert.NotNull(updatedPackage);
            Assert.Single(updatedPackage.Items);
            Assert.Equal(course2.Id, updatedPackage.Items.First().CourseId);
            Assert.Equal(0, updatedPackage.Items.First().DisplayOrder);
        }

        [Fact]
        public async Task UpdatePackage_WithNonExistentCourse_ShouldReturnBadRequest()
        {
            var db = GetDatabaseContext();
            var package = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Valid Bundle",
                CreatedAt = DateTime.UtcNow
            };
            await db.CoursePackages.AddAsync(package);
            await db.SaveChangesAsync();

            var controller = CreateController(db);
            var badId = Guid.NewGuid();
            var updateInput = new UpdatePackageInput
            {
                CourseIds = new List<Guid> { badId }
            };

            var actionResult = await controller.UpdatePackage(package.Id, updateInput);
            var badRequest = Assert.IsType<BadRequestObjectResult>(actionResult);
            Assert.Contains(badId.ToString(), badRequest.Value?.ToString());
        }

        [Fact]
        public async Task DeletePackage_ShouldArchivePackageWithoutCycleExceptions()
        {
            var db = GetDatabaseContext();
            var package = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Bundle To Delete",
                IsPublished = true,
                IsArchived = false,
                CreatedAt = DateTime.UtcNow
            };
            await db.CoursePackages.AddAsync(package);
            await db.SaveChangesAsync();

            var mockAudit = new Mock<IAuditLogService>();
            var controller = CreateController(db, mockAudit);

            var actionResult = await controller.DeletePackage(package.Id);
            Assert.IsType<OkObjectResult>(actionResult);

            var archived = await db.CoursePackages.FindAsync(package.Id);
            Assert.NotNull(archived);
            Assert.True(archived.IsArchived);
            Assert.False(archived.IsPublished);

            mockAudit.Verify(a => a.LogActionAsync(
                "admin_user",
                "ARCHIVE_PACKAGE",
                $"Package:{package.Id}",
                It.IsNotNull<string>(),
                It.IsNotNull<string>()
            ), Times.Once);
        }

        [Fact]
        public void DatabaseMigration_V20_ShouldExistAndContainValidSql()
        {
            var baseDir = AppContext.BaseDirectory;
            var pathsToTry = new[]
            {
                System.IO.Path.Combine(baseDir, "..", "..", "..", "..", "deployment", "db", "migrations", "V20__Add_Package_Allowed_Platforms.sql"),
                System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "deployment", "db", "migrations", "V20__Add_Package_Allowed_Platforms.sql"),
                System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "..", "deployment", "db", "migrations", "V20__Add_Package_Allowed_Platforms.sql"),
                System.IO.Path.Combine(baseDir, "..", "..", "..", "..", "..", "deployment", "db", "migrations", "V20__Add_Package_Allowed_Platforms.sql")
            };

            string? foundPath = pathsToTry.FirstOrDefault(p => System.IO.File.Exists(System.IO.Path.GetFullPath(p)));
            Assert.NotNull(foundPath);

            var sql = System.IO.File.ReadAllText(foundPath);
            Assert.Contains("ALTER TABLE course_packages", sql, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("allowed_platforms", sql, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("UPDATE course_packages", sql, StringComparison.OrdinalIgnoreCase);
        }

        [Fact]
        public async Task AdminController_CreateAndUpdatePackage_WithAllowedPlatforms_ShouldPersistAndAuditCorrectly()
        {
            var db = GetDatabaseContext();
            var course = new Course { Id = Guid.NewGuid(), Title = "Test Course", Version = 1 };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var mockAudit = new Mock<IAuditLogService>();
            var controller = CreateController(db, mockAudit);

            // 1. Create with specific platforms
            var createInput = new CreatePackageInput
            {
                Title = "Bazaar Exclusive Bundle",
                AllowedPlatforms = "bazaar,myket",
                CourseIds = new List<Guid> { course.Id }
            };

            var createResult = await controller.CreatePackage(createInput);
            Assert.IsType<OkObjectResult>(createResult);

            var created = await db.CoursePackages.FirstOrDefaultAsync(p => p.Title == "Bazaar Exclusive Bundle");
            Assert.NotNull(created);
            Assert.Equal("bazaar,myket", created.AllowedPlatforms);

            // 2. Update allowed platforms
            var updateInput = new UpdatePackageInput
            {
                AllowedPlatforms = "zarinpal,bazaar,myket,googleplay"
            };

            var updateResult = await controller.UpdatePackage(created.Id, updateInput);
            Assert.IsType<OkObjectResult>(updateResult);

            var updated = await db.CoursePackages.FindAsync(created.Id);
            Assert.NotNull(updated);
            Assert.Equal("zarinpal,bazaar,myket,googleplay", updated.AllowedPlatforms);
        }

        [Fact]
        public async Task PackageController_GetPackages_WithPlatformFilter_ShouldFilterCorrectly()
        {
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();

            var course1 = new Course { Id = Guid.NewGuid(), Title = "Course 1", Price = 0, IsPublished = true, AllowedPlatforms = "zarinpal,bazaar" };
            var course2 = new Course { Id = Guid.NewGuid(), Title = "Course 2", Price = 0, IsPublished = true, AllowedPlatforms = "zarinpal" };
            await db.Courses.AddRangeAsync(course1, course2);

            // Package 1: Zarinpal only
            var pkgZarinpalOnly = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Zarinpal Direct Package",
                Price = 100000,
                IsPublished = true,
                AllowedPlatforms = "zarinpal",
                CreatedAt = DateTime.UtcNow
            };
            pkgZarinpalOnly.Items.Add(new CoursePackageItem { PackageId = pkgZarinpalOnly.Id, CourseId = course1.Id, DisplayOrder = 0 });

            // Package 2: Bazaar only
            var pkgBazaarOnly = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Bazaar Exclusive Package",
                Price = 200000,
                IsPublished = true,
                AllowedPlatforms = "bazaar",
                CreatedAt = DateTime.UtcNow
            };
            pkgBazaarOnly.Items.Add(new CoursePackageItem { PackageId = pkgBazaarOnly.Id, CourseId = course1.Id, DisplayOrder = 0 });

            // Package 3: Multi-platform (Zarinpal, Bazaar, Myket)
            var pkgMulti = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Multi Platform Package",
                Price = 300000,
                IsPublished = true,
                AllowedPlatforms = "zarinpal,bazaar,myket",
                CreatedAt = DateTime.UtcNow
            };
            pkgMulti.Items.Add(new CoursePackageItem { PackageId = pkgMulti.Id, CourseId = course1.Id, DisplayOrder = 0 });

            await db.CoursePackages.AddRangeAsync(pkgZarinpalOnly, pkgBazaarOnly, pkgMulti);
            await db.SaveChangesAsync();

            var controller = new PackageController(db);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act 1: Query with platform = "bazaar"
            var resultBazaar = await controller.GetPackages(platform: "bazaar");
            var okBazaar = Assert.IsType<OkObjectResult>(resultBazaar);
            var listBazaar = (Assert.IsAssignableFrom<System.Collections.Generic.IEnumerable<object>>(okBazaar.Value)).ToList();

            // Assert 1: Only Bazaar Exclusive Package and Multi Platform Package are returned
            Assert.Equal(2, listBazaar.Count);
            Assert.DoesNotContain(listBazaar, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Zarinpal Direct Package");
            Assert.Contains(listBazaar, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Bazaar Exclusive Package");
            Assert.Contains(listBazaar, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Multi Platform Package");

            // Act 2: Verify X-App-Platform header fallback
            controller.ControllerContext.HttpContext.Request.Headers["X-App-Platform"] = "myket";
            var resultMyket = await controller.GetPackages(platform: null);
            var okMyket = Assert.IsType<OkObjectResult>(resultMyket);
            var listMyket = (Assert.IsAssignableFrom<System.Collections.Generic.IEnumerable<object>>(okMyket.Value)).ToList();

            Assert.Single(listMyket);
            Assert.Equal("Multi Platform Package", (string)listMyket.First().GetType().GetProperty("title")!.GetValue(listMyket.First())!);
        }

        [Fact]
        public async Task BackfillMissingChecksumsAsync_NormalizesLegacyGrammarPackage_ExtractsOptions()
        {
            var db = GetDatabaseContext();
            var courseId = Guid.NewGuid();
            var tempRoot = Path.Combine(Path.GetTempPath(), $"test_backfill_{Guid.NewGuid()}");
            Directory.CreateDirectory(tempRoot);
            var coursesFolder = Path.Combine(tempRoot, "courses");
            Directory.CreateDirectory(coursesFolder);

            try
            {
                var zipName = $"{courseId}.zip";
                var zipPath = Path.Combine(coursesFolder, zipName);

                // Create legacy package with intro_grammar/templateEmpty.db (firstoption .. fourthoption)
                var tempPkgDir = Path.Combine(Path.GetTempPath(), $"pkg_raw_{Guid.NewGuid()}");
                var subDir = Path.Combine(tempPkgDir, "intro_grammar");
                Directory.CreateDirectory(subDir);
                var rawDbPath = Path.Combine(subDir, "templateEmpty.db");

                using (var conn = new SqliteConnection($"Data Source={rawDbPath}"))
                {
                    await conn.OpenAsync();
                    using var createCmd = conn.CreateCommand();
                    createCmd.CommandText = @"
                        CREATE TABLE cards (
                            number INTEGER,
                            questions TEXT,
                            firstoption TEXT,
                            secondoption TEXT,
                            thirdoption TEXT,
                            fourthoption TEXT,
                            answer TEXT
                        );
                        INSERT INTO cards (number, questions, firstoption, secondoption, thirdoption, fourthoption, answer)
                        VALUES (1, 'Rule 1', 'NULL', 'NULL', 'NULL', 'NULL', 'I am');
                        INSERT INTO cards (number, questions, firstoption, secondoption, thirdoption, fourthoption, answer)
                        VALUES (18, 'She _____ my best friend.', 'am', 'is', 'are', 'be', 'is');
                    ";
                    await createCmd.ExecuteNonQueryAsync();
                }
                SqliteConnection.ClearAllPools();

                ZipFile.CreateFromDirectory(tempPkgDir, zipPath);
                Directory.Delete(tempPkgDir, true);

                var course = new Course
                {
                    Id = courseId,
                    Title = "grammar_intro",
                    DownloadUrl = $"/courses/{zipName}",
                    ChecksumSha256 = null,
                    Version = 1,
                    Price = 0.0m
                };
                await db.Courses.AddAsync(course);
                await db.SaveChangesAsync();

                // Act
                await ChecksumBackfiller.BackfillMissingChecksumsAsync(db, tempRoot, _ => { });

                // Assert: zip was normalized to compliant package with course.db
                using var archive = ZipFile.OpenRead(zipPath);
                var entry = archive.GetEntry("course.db");
                Assert.NotNull(entry);

                var extractedCourseDb = Path.Combine(tempRoot, $"verified_course_{Guid.NewGuid()}.db");
                entry.ExtractToFile(extractedCourseDb);

                using (var vConn = new SqliteConnection($"Data Source={extractedCourseDb}"))
                {
                    await vConn.OpenAsync();
                    using var qCmd = vConn.CreateCommand();
                    qCmd.CommandText = "SELECT card_number, question_text, answer_text, options FROM cards ORDER BY card_number";
                    using var reader = await qCmd.ExecuteReaderAsync();

                    // Card 1
                    Assert.True(await reader.ReadAsync());
                    Assert.Equal(1, reader.GetInt32(0));
                    Assert.True(reader.IsDBNull(3)); // Literal 'NULL' should be converted to DBNull

                    // Card 18
                    Assert.True(await reader.ReadAsync());
                    Assert.Equal(18, reader.GetInt32(0));
                    Assert.Equal("She _____ my best friend.", reader.GetString(1));
                    Assert.Equal("is", reader.GetString(2));
                    Assert.False(reader.IsDBNull(3));
                    var optionsStr = reader.GetString(3);
                    Assert.Equal("[\"am\",\"is\",\"are\",\"be\"]", optionsStr);
                }
                SqliteConnection.ClearAllPools();
            }
            finally
            {
                if (Directory.Exists(tempRoot))
                {
                    try { Directory.Delete(tempRoot, true); } catch { }
                }
            }
        }
    }
}
