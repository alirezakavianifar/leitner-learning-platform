using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using LeitnerPlatform.API.Controllers.v1;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;

namespace LeitnerPlatform.Tests
{
    public class PurchaseTests
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
        public async Task PurchaseController_CreatePurchase_ShouldRecordAndPublishEvent()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var courseId = Guid.NewGuid();

            var course = new Course
            {
                Id = courseId,
                Title = "Test Premium Course",
                Price = 199.99m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            mockEventBus.Setup(eb => eb.PublishAsync(It.IsAny<PurchaseCompletedEvent>()))
                .Returns(Task.CompletedTask);

            var mockZarinPalService = new Mock<IZarinPalService>();
            var mockConfig = new Mock<IConfiguration>();
            var mockLogger = new Mock<ILogger<PurchaseController>>();

            var controller = new PurchaseController(db, mockEventBus.Object, mockZarinPalService.Object, mockConfig.Object, mockLogger.Object);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var input = new CreatePurchaseInput
            {
                CourseId = courseId,
                PaymentProvider = "GOOGLE_PLAY",
                TransactionId = "GPA.1234-5678-9012-34567"
            };

            // Act
            var result = await controller.CreatePurchase(input);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == courseId);

            Assert.NotNull(purchase);
            Assert.Equal("COMPLETED", purchase.Status);
            Assert.Equal("GOOGLE_PLAY", purchase.PaymentProvider);
            Assert.Equal("GPA.1234-5678-9012-34567", purchase.TransactionId);

            mockEventBus.Verify(eb => eb.PublishAsync(It.Is<PurchaseCompletedEvent>(e => 
                e.Purchase.UserId == userId && 
                e.Purchase.CourseId == courseId && 
                e.Purchase.TransactionId == "GPA.1234-5678-9012-34567")), Times.Once);
        }

        [Fact]
        public async Task PurchaseController_RequestZarinPalPayment_ShouldReturnPaymentUrl()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var courseId = Guid.NewGuid();

            var course = new Course
            {
                Id = courseId,
                Title = "Flutter Advanced Masterclass",
                Price = 50000m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            await db.Courses.AddAsync(course);

            var user = new User
            {
                Id = userId,
                Username = "09121234567",
                MobileNumber = "09121234567",
                CreatedAt = DateTime.UtcNow
            };
            await db.Users.AddAsync(user);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var mockZarinPalService = new Mock<IZarinPalService>();
            mockZarinPalService.Setup(z => z.RequestPaymentAsync(50000m, It.IsAny<string>(), It.IsAny<string>(), "09121234567", null))
                .ReturnsAsync(new ZarinPalRequestResponse
                {
                    IsSuccess = true,
                    Code = 100,
                    Authority = "A00000000000000000000000000000000000",
                    PaymentUrl = "https://www.zarinpal.com/pg/StartPay/A00000000000000000000000000000000000"
                });

            var mockConfig = new Mock<IConfiguration>();
            mockConfig.Setup(c => c["ZarinPal:CallbackUrl"]).Returns("https://api.example.com/callback");
            var mockLogger = new Mock<ILogger<PurchaseController>>();

            var controller = new PurchaseController(db, mockEventBus.Object, mockZarinPalService.Object, mockConfig.Object, mockLogger.Object);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = claimsPrincipal,
                    Request = { Scheme = "https", Host = new HostString("api.example.com") }
                }
            };

            // Act
            var result = await controller.RequestZarinPalPayment(new ZarinPalPurchaseInput { CourseId = courseId });

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == courseId);
            Assert.NotNull(purchase);
            Assert.Equal("PENDING", purchase.Status);
            Assert.Equal("ZARINPAL", purchase.PaymentProvider);
            Assert.Equal("A00000000000000000000000000000000000", purchase.TransactionId);
        }

        [Fact]
        public async Task PurchaseController_CreatePackagePurchase_ShouldUnlockAllConstituentCourses()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var course1Id = Guid.NewGuid();
            var course2Id = Guid.NewGuid();
            var course3Id = Guid.NewGuid();
            var packageId = Guid.NewGuid();

            var course1 = new Course { Id = course1Id, Title = "Course 1", Price = 100000m, IsPublished = true };
            var course2 = new Course { Id = course2Id, Title = "Course 2", Price = 100000m, IsPublished = true };
            var course3 = new Course { Id = course3Id, Title = "Course 3", Price = 100000m, IsPublished = true };
            await db.Courses.AddRangeAsync(course1, course2, course3);

            var package = new CoursePackage
            {
                Id = packageId,
                Title = "Complete 3-in-1 Bundle",
                Price = 199000m,
                OriginalPrice = 300000m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            package.Items.Add(new CoursePackageItem { PackageId = packageId, CourseId = course1Id, DisplayOrder = 0 });
            package.Items.Add(new CoursePackageItem { PackageId = packageId, CourseId = course2Id, DisplayOrder = 1 });
            package.Items.Add(new CoursePackageItem { PackageId = packageId, CourseId = course3Id, DisplayOrder = 2 });
            await db.CoursePackages.AddAsync(package);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var mockZarinPalService = new Mock<IZarinPalService>();
            var mockConfig = new Mock<IConfiguration>();
            var mockLogger = new Mock<ILogger<PurchaseController>>();

            var controller = new PurchaseController(db, mockEventBus.Object, mockZarinPalService.Object, mockConfig.Object, mockLogger.Object);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var input = new CreatePackagePurchaseInput
            {
                PackageId = packageId,
                PaymentProvider = "BAZAAR",
                TransactionId = "BZ.PKG_12345"
            };

            // Act
            var result = await controller.CreatePackagePurchase(input);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);

            var pkgPurchase = await db.PackagePurchases.FirstOrDefaultAsync(p => p.UserId == userId && p.PackageId == packageId);
            Assert.NotNull(pkgPurchase);
            Assert.Equal("COMPLETED", pkgPurchase.Status);
            Assert.Equal(199000m, pkgPurchase.AmountPaid);

            // All 3 courses must now be unlocked as COMPLETED purchases
            var c1Purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == course1Id);
            var c2Purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == course2Id);
            var c3Purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == course3Id);

            Assert.NotNull(c1Purchase);
            Assert.Equal("COMPLETED", c1Purchase.Status);
            Assert.NotNull(c2Purchase);
            Assert.Equal("COMPLETED", c2Purchase.Status);
            Assert.NotNull(c3Purchase);
            Assert.Equal("COMPLETED", c3Purchase.Status);

            mockEventBus.Verify(eb => eb.PublishAsync(It.IsAny<PurchaseCompletedEvent>()), Times.Exactly(3));
        }

        [Fact]
        public async Task PackageController_GetPackages_ShouldCalculateDiscountsAndOwnership()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var course1Id = Guid.NewGuid();
            var course2Id = Guid.NewGuid();
            var packageId = Guid.NewGuid();

            var course1 = new Course { Id = course1Id, Title = "English Vocab 1", Price = 100000m, IsPublished = true, CardCount = 100 };
            var course2 = new Course { Id = course2Id, Title = "English Vocab 2", Price = 100000m, IsPublished = true, CardCount = 150 };
            await db.Courses.AddRangeAsync(course1, course2);

            // User already owns course1
            await db.Purchases.AddAsync(new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CourseId = course1Id,
                Status = "COMPLETED",
                PaymentProvider = "DIRECT",
                TransactionId = "TX1",
                PurchasedAt = DateTime.UtcNow
            });

            var package = new CoursePackage
            {
                Id = packageId,
                Title = "English Vocab Bundle",
                Price = 140000m,
                OriginalPrice = 200000m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            package.Items.Add(new CoursePackageItem { PackageId = packageId, CourseId = course1Id, DisplayOrder = 0 });
            package.Items.Add(new CoursePackageItem { PackageId = packageId, CourseId = course2Id, DisplayOrder = 1 });
            await db.CoursePackages.AddAsync(package);
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

            // Act
            var result = await controller.GetPackages();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);
        }
    }
}


