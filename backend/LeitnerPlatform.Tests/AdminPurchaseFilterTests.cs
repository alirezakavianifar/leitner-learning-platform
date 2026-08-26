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

        [Fact]
        public async Task ToggleCourseAccess_Grant_ShouldCreateAdminGrantPurchase()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "GiftedUser", MobileNumber = "09120003344", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var course = new Course { Id = Guid.NewGuid(), Title = "Advanced English", Price = 500000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            var result = Assert.IsType<OkObjectResult>(await controller.ToggleCourseAccess(user.Id, course.Id, new ToggleCourseAccessInput
            {
                GrantAccess = true,
                Reason = "VIP Scholarship Grant"
            }));

            var purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == user.Id && p.CourseId == course.Id);
            Assert.NotNull(purchase);
            Assert.Equal("COMPLETED", purchase.Status);
            Assert.Equal("ADMIN_GRANT", purchase.PaymentProvider);
            Assert.StartsWith("MANUAL_", purchase.TransactionId);
        }

        [Fact]
        public async Task ToggleCourseAccess_Revoke_ShouldSetStatusToRefunded()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "RevokeUser", MobileNumber = "09120005566", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var course = new Course { Id = Guid.NewGuid(), Title = "Grammar 101", Price = 100000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddAsync(course);

            var purchase = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                CourseId = course.Id,
                PaymentProvider = "ADMIN_GRANT",
                TransactionId = "MANUAL_TEST",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            await db.Purchases.AddAsync(purchase);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            var result = Assert.IsType<OkObjectResult>(await controller.ToggleCourseAccess(user.Id, course.Id, new ToggleCourseAccessInput
            {
                GrantAccess = false,
                Reason = "Fraud check / Access revoked"
            }));

            var updatedPurchase = await db.Purchases.FirstOrDefaultAsync(p => p.Id == purchase.Id);
            Assert.NotNull(updatedPurchase);
            Assert.Equal("REFUNDED", updatedPurchase.Status);
        }

        [Fact]
        public async Task TogglePackageAccess_Grant_ShouldUnlockAllConstituentCourses()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "BundleUser", MobileNumber = "09127778899", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var c1 = new Course { Id = Guid.NewGuid(), Title = "Course A", Price = 100000, CreatedAt = DateTime.UtcNow };
            var c2 = new Course { Id = Guid.NewGuid(), Title = "Course B", Price = 150000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddRangeAsync(c1, c2);

            var package = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = "Mega English Bundle",
                Price = 200000,
                CreatedAt = DateTime.UtcNow
            };
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = c1.Id, DisplayOrder = 0 });
            package.Items.Add(new CoursePackageItem { PackageId = package.Id, CourseId = c2.Id, DisplayOrder = 1 });
            await db.CoursePackages.AddAsync(package);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            var result = Assert.IsType<OkObjectResult>(await controller.TogglePackageAccess(user.Id, package.Id, new ToggleCourseAccessInput
            {
                GrantAccess = true,
                Reason = "Special Package Promotion"
            }));

            var pkgPurchase = await db.PackagePurchases.FirstOrDefaultAsync(p => p.UserId == user.Id && p.PackageId == package.Id);
            Assert.NotNull(pkgPurchase);
            Assert.Equal("COMPLETED", pkgPurchase.Status);
            Assert.Equal("ADMIN_GRANT", pkgPurchase.PaymentProvider);

            var p1 = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == user.Id && p.CourseId == c1.Id);
            var p2 = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == user.Id && p.CourseId == c2.Id);
            Assert.NotNull(p1);
            Assert.NotNull(p2);
            Assert.Equal("COMPLETED", p1.Status);
            Assert.Equal("COMPLETED", p2.Status);
            Assert.Equal("ADMIN_GRANT_BUNDLE", p1.PaymentProvider);
            Assert.Equal("ADMIN_GRANT_BUNDLE", p2.PaymentProvider);
        }

        [Fact]
        public async Task QuickGrantAccess_ByMobile_ShouldFindUserAndGrantCourse()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "MobileUser", MobileNumber = "09301112233", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var course = new Course { Id = Guid.NewGuid(), Title = "Quick Course", Price = 250000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddAsync(course);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            var result = Assert.IsType<OkObjectResult>(await controller.QuickGrantAccess(new QuickGrantInput
            {
                MobileNumber = " 09301112233 ",
                CourseId = course.Id,
                Reason = "Quick grant by phone"
            }));

            var purchase = await db.Purchases.FirstOrDefaultAsync(p => p.UserId == user.Id && p.CourseId == course.Id);
            Assert.NotNull(purchase);
            Assert.Equal("COMPLETED", purchase.Status);
            Assert.Equal("ADMIN_GRANT", purchase.PaymentProvider);
        }

        [Fact]
        public async Task WipeUserPurchases_ShouldSetAllActiveCoursesAndPackagesToRefunded()
        {
            var db = GetDatabaseContext();
            var user1 = new User { Id = Guid.NewGuid(), Username = "User1", MobileNumber = "09121111111", CreatedAt = DateTime.UtcNow };
            var user2 = new User { Id = Guid.NewGuid(), Username = "User2", MobileNumber = "09122222222", CreatedAt = DateTime.UtcNow };
            await db.Users.AddRangeAsync(user1, user2);

            var c1 = new Course { Id = Guid.NewGuid(), Title = "Course 1", Price = 100000, CreatedAt = DateTime.UtcNow };
            var c2 = new Course { Id = Guid.NewGuid(), Title = "Course 2", Price = 150000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddRangeAsync(c1, c2);

            var pkg = new CoursePackage { Id = Guid.NewGuid(), Title = "Pkg 1", Price = 200000, CreatedAt = DateTime.UtcNow };
            pkg.Items.Add(new CoursePackageItem { PackageId = pkg.Id, CourseId = c1.Id, DisplayOrder = 0 });
            await db.CoursePackages.AddAsync(pkg);

            // User 1 has 2 completed course purchases and 1 package purchase
            var u1_p1 = new Purchase { Id = Guid.NewGuid(), UserId = user1.Id, CourseId = c1.Id, Status = "COMPLETED", PaymentProvider = "ZARINPAL", TransactionId = "TX1", PurchasedAt = DateTime.UtcNow };
            var u1_p2 = new Purchase { Id = Guid.NewGuid(), UserId = user1.Id, CourseId = c2.Id, Status = "COMPLETED", PaymentProvider = "ADMIN_GRANT", TransactionId = "TX2", PurchasedAt = DateTime.UtcNow };
            var u1_pkg = new PackagePurchase { Id = Guid.NewGuid(), UserId = user1.Id, PackageId = pkg.Id, Status = "COMPLETED", PaymentProvider = "ZARINPAL", TransactionId = "PKG1", PurchasedAt = DateTime.UtcNow };

            // User 2 has 1 completed course purchase
            var u2_p1 = new Purchase { Id = Guid.NewGuid(), UserId = user2.Id, CourseId = c1.Id, Status = "COMPLETED", PaymentProvider = "ZARINPAL", TransactionId = "TX3", PurchasedAt = DateTime.UtcNow };

            await db.Purchases.AddRangeAsync(u1_p1, u1_p2, u2_p1);
            await db.PackagePurchases.AddAsync(u1_pkg);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            // Wipe User 1 purchases
            var result = Assert.IsType<OkObjectResult>(await controller.WipeUserPurchases(user1.Id, new WipeUserPurchasesInput
            {
                Reason = "Violation of terms or manual reset"
            }));

            // Check User 1 purchases are all REFUNDED
            var u1_p1_after = await db.Purchases.FindAsync(u1_p1.Id);
            var u1_p2_after = await db.Purchases.FindAsync(u1_p2.Id);
            var u1_pkg_after = await db.PackagePurchases.FindAsync(u1_pkg.Id);

            Assert.NotNull(u1_p1_after);
            Assert.NotNull(u1_p2_after);
            Assert.NotNull(u1_pkg_after);
            Assert.Equal("REFUNDED", u1_p1_after.Status);
            Assert.Equal("REFUNDED", u1_p2_after.Status);
            Assert.Equal("REFUNDED", u1_pkg_after.Status);

            // Check User 2 purchases remain intact (COMPLETED)
            var u2_p1_after = await db.Purchases.FindAsync(u2_p1.Id);
            Assert.NotNull(u2_p1_after);
            Assert.Equal("COMPLETED", u2_p1_after.Status);
        }

        [Fact]
        public async Task TogglePackageAccess_Revoke_ShouldRevokeAllConstituentCourses()
        {
            var db = GetDatabaseContext();
            var user = new User { Id = Guid.NewGuid(), Username = "PkgRevokeUser", MobileNumber = "09129998877", CreatedAt = DateTime.UtcNow };
            await db.Users.AddAsync(user);

            var c1 = new Course { Id = Guid.NewGuid(), Title = "Bundle Course 1", Price = 100000, CreatedAt = DateTime.UtcNow };
            var c2 = new Course { Id = Guid.NewGuid(), Title = "Bundle Course 2", Price = 150000, CreatedAt = DateTime.UtcNow };
            await db.Courses.AddRangeAsync(c1, c2);

            var pkg = new CoursePackage { Id = Guid.NewGuid(), Title = "Test Bundle", Price = 200000, CreatedAt = DateTime.UtcNow };
            pkg.Items.Add(new CoursePackageItem { PackageId = pkg.Id, CourseId = c1.Id, DisplayOrder = 0 });
            pkg.Items.Add(new CoursePackageItem { PackageId = pkg.Id, CourseId = c2.Id, DisplayOrder = 1 });
            await db.CoursePackages.AddAsync(pkg);

            var pkgPurchase = new PackagePurchase { Id = Guid.NewGuid(), UserId = user.Id, PackageId = pkg.Id, Status = "COMPLETED", PaymentProvider = "ZARINPAL", TransactionId = "TXP1", PurchasedAt = DateTime.UtcNow };
            var p1 = new Purchase { Id = Guid.NewGuid(), UserId = user.Id, CourseId = c1.Id, Status = "COMPLETED", PaymentProvider = "ZARINPAL", TransactionId = "TXC1", PurchasedAt = DateTime.UtcNow };
            var p2 = new Purchase { Id = Guid.NewGuid(), UserId = user.Id, CourseId = c2.Id, Status = "COMPLETED", PaymentProvider = "ZARINPAL", TransactionId = "TXC2", PurchasedAt = DateTime.UtcNow };

            await db.PackagePurchases.AddAsync(pkgPurchase);
            await db.Purchases.AddRangeAsync(p1, p2);
            await db.SaveChangesAsync();

            var controller = CreateController(db);

            // Revoke package access
            var result = Assert.IsType<OkObjectResult>(await controller.TogglePackageAccess(user.Id, pkg.Id, new ToggleCourseAccessInput
            {
                GrantAccess = false,
                Reason = "Refunded package"
            }));

            var pkgAfter = await db.PackagePurchases.FindAsync(pkgPurchase.Id);
            var p1After = await db.Purchases.FindAsync(p1.Id);
            var p2After = await db.Purchases.FindAsync(p2.Id);

            Assert.NotNull(pkgAfter);
            Assert.NotNull(p1After);
            Assert.NotNull(p2After);
            Assert.Equal("REFUNDED", pkgAfter.Status);
            Assert.Equal("REFUNDED", p1After.Status);
            Assert.Equal("REFUNDED", p2After.Status);
        }
    }
}
