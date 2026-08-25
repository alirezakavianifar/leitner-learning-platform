using System;
using System.IO;
using System.Security.Claims;
using System.Text;
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
    public class AdminPurchaseFilterTests
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

        private AdminController CreateController(LeitnerDbContext db)
        {
            var mockEventBus = new Mock<IEventBus>();
            var mockAudit = new Mock<IAuditLogService>();
            var mockLogger = new Mock<ILogger<AdminController>>();

            var controller = new AdminController(db, mockEventBus.Object, mockAudit.Object, mockLogger.Object);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, "superadmin"),
                new Claim(ClaimTypes.Role, "Admin")
            }, "mock"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            return controller;
        }

        [Fact]
        public async Task GetPurchases_ShouldFilterBySearch_MobileAndUsernameAndTransactionId()
        {
            var db = GetDatabaseContext();
            var user1 = new User { Id = Guid.NewGuid(), Username = "Sara_Learner", MobileNumber = "09121112233", CreatedAt = DateTime.UtcNow };
            var user2 = new User { Id = Guid.NewGuid(), Username = "Reza_Tech", MobileNumber = "09359998877", CreatedAt = DateTime.UtcNow };
            await db.Users.AddRangeAsync(user1, user2);

            var course1 = new Course { Id = Guid.NewGuid(), Title = "504 Essential Words", Price = 150000, CreatedAt = DateTime.UtcNow };
            var course2 = new Course { Id = Guid.NewGuid(), Title = "1100 Words You Need", Price = 250000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddRangeAsync(course1, course2);

            var p1 = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = user1.Id,
                CourseId = course1.Id,
                PaymentProvider = "ZARINPAL",
                TransactionId = "ZP_REF_1001",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            var p2 = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = user2.Id,
                CourseId = course2.Id,
                PaymentProvider = "CAFE_BAZAAR",
                TransactionId = "BZ_TOKEN_999",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            await db.Purchases.AddRangeAsync(p1, p2);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            // 1. Search by mobile number substring
            var result1 = Assert.IsType<OkObjectResult>(await controller.GetPurchases(search: "0912", status: null, gateway: null, courseId: null, fromDate: null, toDate: null));
            var totalCount1 = (int)result1.Value!.GetType().GetProperty("total_count")!.GetValue(result1.Value)!;
            Assert.Equal(1, totalCount1);

            // 2. Search by transaction ID
            var result2 = Assert.IsType<OkObjectResult>(await controller.GetPurchases(search: "BZ_TOKEN", status: null, gateway: null, courseId: null, fromDate: null, toDate: null));
            var totalCount2 = (int)result2.Value!.GetType().GetProperty("total_count")!.GetValue(result2.Value)!;
            Assert.Equal(1, totalCount2);
        }

        [Fact]
        public async Task GetPurchases_ShouldFilterByStatusAndCalculateRevenue()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "Tester", MobileNumber = "09180001122", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var course = new Course { Id = Guid.NewGuid(), Title = "English Vocab", Price = 200000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddAsync(course);

            var p1 = new Purchase { Id = Guid.NewGuid(), UserId = user.Id, CourseId = course.Id, PaymentProvider = "ZARINPAL", TransactionId = "TX1", Status = "COMPLETED", PurchasedAt = DateTime.UtcNow };
            var p2 = new Purchase { Id = Guid.NewGuid(), UserId = user.Id, CourseId = course.Id, PaymentProvider = "ZARINPAL", TransactionId = "TX2", Status = "PENDING", PurchasedAt = DateTime.UtcNow };
            await db.Purchases.AddRangeAsync(p1, p2);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            var result = Assert.IsType<OkObjectResult>(await controller.GetPurchases(search: null, status: "COMPLETED", gateway: null, courseId: null, fromDate: null, toDate: null));
            var totalCount = (int)result.Value!.GetType().GetProperty("total_count")!.GetValue(result.Value)!;
            var totalRevenue = (long)result.Value!.GetType().GetProperty("total_revenue")!.GetValue(result.Value)!;
            Assert.Equal(1, totalCount);
            Assert.Equal(200000, totalRevenue);
        }

        [Fact]
        public async Task ExportPurchases_ShouldReturnCsvFileResult()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "Buyer", MobileNumber = "09101112233", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var course = new Course { Id = Guid.NewGuid(), Title = "Mastering 504", Price = 300000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddAsync(course);

            var purchase = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                CourseId = course.Id,
                PaymentProvider = "ZARINPAL",
                TransactionId = "ZP_EXP_777",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            await db.Purchases.AddAsync(purchase);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            var result = await controller.ExportPurchases(search: null, status: null, gateway: null, courseId: null, fromDate: null, toDate: null) as FileContentResult;
            Assert.NotNull(result);
            Assert.Equal("text/csv; charset=utf-8", result.ContentType);
            Assert.Contains(".csv", result.FileDownloadName);

            var csvContent = Encoding.UTF8.GetString(result.FileContents);
            Assert.Contains("شناسه خرید", csvContent);
            Assert.Contains("Buyer", csvContent);
            Assert.Contains("09101112233", csvContent);
            Assert.Contains("Mastering 504", csvContent);
            Assert.Contains("300000", csvContent);
        }
    }
}
