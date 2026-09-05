using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
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
    public class CourseTests
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

        [Fact]
        public async Task CourseController_GetCourses_ShouldReturnCatalogAndCheckPurchases()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();

            var courseFree = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Free Course",
                Price = 0.00m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };

            var coursePaidUnpurchased = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Paid Unpurchased Course",
                Price = 100.00m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };

            var coursePaidPurchased = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Paid Purchased Course",
                Price = 200.00m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };

            await db.Courses.AddRangeAsync(courseFree, coursePaidUnpurchased, coursePaidPurchased);

            // Add purchase for PaidPurchased
            var purchase = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CourseId = coursePaidPurchased.Id,
                PaymentProvider = "DIRECT",
                TransactionId = "TX_TEST_123",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            await db.Purchases.AddAsync(purchase);
            await db.SaveChangesAsync();

            var controller = new CourseController(db);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act
            var result = await controller.GetCourses();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var catalog = Assert.IsAssignableFrom<System.Collections.Generic.IEnumerable<object>>(okResult.Value).ToList();

            Assert.Equal(3, catalog.Count);

            // Verify properties
            foreach (var item in catalog)
            {
                var type = item.GetType();
                var id = (Guid)type.GetProperty("id")!.GetValue(item)!;
                var isPurchased = (bool)type.GetProperty("is_purchased")!.GetValue(item)!;

                if (id == courseFree.Id)
                {
                    Assert.True(isPurchased);
                }
                else if (id == coursePaidUnpurchased.Id)
                {
                    Assert.False(isPurchased);
                }
                else if (id == coursePaidPurchased.Id)
                {
                    Assert.True(isPurchased);
                }
            }
        }

        [Fact]
        public async Task CourseController_RequestDownloadToken_ShouldBlockUnpurchased()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();

            var coursePaid = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Paid Course",
                Price = 150.00m,
                IsPublished = true,
                DownloadUrl = "/courses/paid.zip",
                ChecksumSha256 = "sha256_paid_checksum",
                CreatedAt = DateTime.UtcNow
            };

            await db.Courses.AddAsync(coursePaid);
            await db.SaveChangesAsync();

            var controller = new CourseController(db);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act - Download Paid Unpurchased Course
            var result = await controller.RequestDownloadToken(coursePaid.Id);

            // Assert
            var forbiddenResult = Assert.IsType<ObjectResult>(result);
            Assert.Equal(403, forbiddenResult.StatusCode);

            // Act - After purchase
            var purchase = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CourseId = coursePaid.Id,
                PaymentProvider = "DIRECT",
                TransactionId = "TX_PAID_OK",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            await db.Purchases.AddAsync(purchase);
            await db.SaveChangesAsync();

            var okResult = await controller.RequestDownloadToken(coursePaid.Id);
            var successResult = Assert.IsType<OkObjectResult>(okResult);
            
            var type = successResult.Value!.GetType();
            var checksum = (string)type.GetProperty("checksum")!.GetValue(successResult.Value)!;
            var token = (string)type.GetProperty("token")!.GetValue(successResult.Value)!;

            Assert.Equal("sha256_paid_checksum", checksum);
            Assert.StartsWith("temp_sec_token_", token);
        }

        [Fact]
        public async Task AdminController_UpdateCourse_ShouldModifyAndLog()
        {
            // Arrange
            var db = GetDatabaseContext();
            var course = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Old Title",
                Category = "Old Category",
                Price = 50.00m,
                IsPublished = false,
                CreatedAt = DateTime.UtcNow
            };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var mockAudit = new Mock<IAuditLogService>();
            
            mockAudit.Setup(a => a.LogActionAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<string>()
            )).Returns(Task.CompletedTask);

            var controller = new AdminController(db, mockEventBus.Object, mockAudit.Object, Mock.Of<ILogger<AdminController>>());
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, "test_admin")
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var updateInput = new AdminCourseUpdateInput
            {
                Title = "New Title",
                Price = 120.00m,
                IsPublished = true
            };

            // Act
            var result = await controller.UpdateCourse(course.Id, updateInput);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var updated = await db.Courses.FindAsync(course.Id);

            Assert.NotNull(updated);
            Assert.Equal("New Title", updated.Title);
            Assert.Equal(120.00m, updated.Price);
            Assert.True(updated.IsPublished);
            Assert.Equal("Old Category", updated.Category); // Retained

            // Verify Audit Log Call
            mockAudit.Verify(a => a.LogActionAsync(
                "test_admin",
                "UPDATE_COURSE_METADATA",
                $"Course:{course.Id}",
                It.Is<string>(s => s.Contains("Old Title")),
                It.Is<string>(s => s.Contains("New Title"))
            ), Times.Once);
        }

        [Fact]
        public async Task AdminController_DeleteCourse_ShouldDeleteAndLog()
        {
            // Arrange
            var db = GetDatabaseContext();
            var course = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Course to Delete",
                CreatedAt = DateTime.UtcNow
            };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var mockAudit = new Mock<IAuditLogService>();

            var controller = new AdminController(db, mockEventBus.Object, mockAudit.Object, Mock.Of<ILogger<AdminController>>());
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, "test_admin")
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act
            var result = await controller.DeleteCourse(course.Id);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var updated = await db.Courses.FindAsync(course.Id);
            Assert.NotNull(updated);
            Assert.True(updated.IsArchived);

            mockAudit.Verify(a => a.LogActionAsync(
                "test_admin",
                "ARCHIVE_COURSE",
                $"Course:{course.Id}",
                It.Is<string>(s => s.Contains("Course to Delete")),
                It.Is<string>(s => s.Contains("true"))
            ), Times.Once);
        }

        [Fact]
        public async Task CourseController_SubmitReport_ShouldStoreReport()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var courseId = Guid.NewGuid();

            var course = new Course
            {
                Id = courseId,
                Title = "Reported Course",
                Price = 0.00m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var controller = new CourseController(db);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var reportInput = new SubmitReportInput
            {
                CourseId = courseId,
                CardNumber = 42,
                ReportText = "Typo in answer field."
            };

            // Act
            var result = await controller.SubmitReport(reportInput);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var resultValue = okResult.Value;
            var type = resultValue!.GetType();
            var success = (bool)type.GetProperty("success")!.GetValue(resultValue)!;
            var reportId = (Guid)type.GetProperty("report_id")!.GetValue(resultValue)!;

            Assert.True(success);
            Assert.NotEqual(Guid.Empty, reportId);

            var storedReport = await db.FlashcardReports.FindAsync(reportId);
            Assert.NotNull(storedReport);
            Assert.Equal(userId, storedReport.UserId);
            Assert.Equal(courseId, storedReport.CourseId);
            Assert.Equal(42, storedReport.CardNumber);
            Assert.Equal("Typo in answer field.", storedReport.ReportText);
            Assert.Equal("PENDING", storedReport.Status);
        }

        [Fact]
        public async Task Course_AllowedPlatforms_ShouldDefaultAndPersistCorrectly()
        {
            // Arrange
            var db = GetDatabaseContext();
            var course = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Multi-Platform Targeted Course",
                Price = 50000m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };

            // Assert entity default
            Assert.Equal("zarinpal,bazaar,myket,googleplay,ios", course.AllowedPlatforms);

            // Act & Assert Custom Platform Persistence
            course.AllowedPlatforms = "zarinpal,bazaar";
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var loaded = await db.Courses.FindAsync(course.Id);
            Assert.NotNull(loaded);
            Assert.Equal("zarinpal,bazaar", loaded.AllowedPlatforms);
        }

        [Fact]
        public void DatabaseMigration_V18_ShouldExistAndContainValidSql()
        {
            var baseDir = AppContext.BaseDirectory;
            var pathsToTry = new[]
            {
                System.IO.Path.Combine(baseDir, "..", "..", "..", "..", "deployment", "db", "migrations", "V18__Add_Course_Allowed_Platforms.sql"),
                System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "deployment", "db", "migrations", "V18__Add_Course_Allowed_Platforms.sql"),
                System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "..", "deployment", "db", "migrations", "V18__Add_Course_Allowed_Platforms.sql"),
                System.IO.Path.Combine(baseDir, "..", "..", "..", "..", "..", "deployment", "db", "migrations", "V18__Add_Course_Allowed_Platforms.sql")
            };

            string? foundPath = pathsToTry.FirstOrDefault(p => System.IO.File.Exists(System.IO.Path.GetFullPath(p)));
            Assert.NotNull(foundPath);

            var sql = System.IO.File.ReadAllText(foundPath);
            Assert.Contains("ALTER TABLE courses", sql, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("allowed_platforms", sql, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("UPDATE courses", sql, StringComparison.OrdinalIgnoreCase);
        }

        [Fact]
        public async Task CourseController_GetCourses_WithPlatformFilter_ShouldFilterCorrectly()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();

            var courseZarinpalOnly = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Zarinpal Direct Course",
                Price = 10000m,
                IsPublished = true,
                AllowedPlatforms = "zarinpal",
                CreatedAt = DateTime.UtcNow
            };

            var courseBazaarOnly = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Bazaar Exclusive Course",
                Price = 20000m,
                IsPublished = true,
                AllowedPlatforms = "bazaar",
                CreatedAt = DateTime.UtcNow
            };

            var courseMulti = new Course
            {
                Id = Guid.NewGuid(),
                Title = "Multi-Store Course",
                Price = 30000m,
                IsPublished = true,
                AllowedPlatforms = "zarinpal,bazaar,myket",
                CreatedAt = DateTime.UtcNow
            };

            await db.Courses.AddRangeAsync(courseZarinpalOnly, courseBazaarOnly, courseMulti);
            await db.SaveChangesAsync();

            var controller = new CourseController(db);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act 1: Query with platform = "bazaar"
            var resultBazaar = await controller.GetCourses(platform: "bazaar");
            var okBazaar = Assert.IsType<OkObjectResult>(resultBazaar);
            var listBazaar = (Assert.IsAssignableFrom<System.Collections.Generic.IEnumerable<object>>(okBazaar.Value)).ToList();

            // Assert 1: Only BazaarOnly and Multi are returned
            Assert.Equal(2, listBazaar.Count);
            Assert.DoesNotContain(listBazaar, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Zarinpal Direct Course");
            Assert.Contains(listBazaar, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Bazaar Exclusive Course");
            Assert.Contains(listBazaar, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Multi-Store Course");

            // Act 2: Query with X-App-Platform header = "premium" (maps to zarinpal)
            controller.ControllerContext.HttpContext.Request.Headers["X-App-Platform"] = "premium";
            var resultPremiumHeader = await controller.GetCourses();
            var okPremium = Assert.IsType<OkObjectResult>(resultPremiumHeader);
            var listPremium = (Assert.IsAssignableFrom<System.Collections.Generic.IEnumerable<object>>(okPremium.Value)).ToList();

            // Assert 2: ZarinpalDirect and Multi are returned, BazaarExclusive is excluded
            Assert.Equal(2, listPremium.Count);
            Assert.Contains(listPremium, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Zarinpal Direct Course");
            Assert.DoesNotContain(listPremium, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Bazaar Exclusive Course");
            Assert.Contains(listPremium, item => (string)item.GetType().GetProperty("title")!.GetValue(item)! == "Multi-Store Course");
        }
    }
}
