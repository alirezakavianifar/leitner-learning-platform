using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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

            var controller = new PurchaseController(db, mockEventBus.Object);
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
    }
}
