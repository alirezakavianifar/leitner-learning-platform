using System;
using System.Collections.Generic;
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
    public class StatisticsTests
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
        public async Task SyncProgress_ShouldVerifyPurchaseAndProcessDeltas()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var courseId = Guid.NewGuid();

            var course = new Course
            {
                Id = courseId,
                Title = "Test Premium Course",
                Price = 100.00m,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };
            var card = new Card
            {
                Id = Guid.NewGuid(),
                CourseId = courseId,
                CardNumber = 42,
                QuestionText = "Q?",
                AnswerText = "A!"
            };

            await db.Courses.AddAsync(course);
            await db.Cards.AddAsync(card);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var controller = new StatisticsController(db, mockEventBus.Object);

            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var syncInput = new ProgressSyncInput
            {
                SyncTime = DateTime.UtcNow,
                ProgressDeltas = new List<ProgressDeltaInput>
                {
                    new ProgressDeltaInput
                    {
                        CourseId = courseId,
                        CardNumber = 42,
                        CurrentBox = 2,
                        LastReviewedAt = DateTime.UtcNow.AddMinutes(-5),
                        NextReviewDue = DateTime.UtcNow.AddDays(3),
                        Trigger = "REVIEW_CORRECT"
                    }
                }
            };

            // Act - Sync when course NOT purchased
            var result = await controller.SyncProgress(syncInput);

            // Assert - Should skip unpurchased
            var okResult = Assert.IsType<OkObjectResult>(result);
            var resultType = okResult.Value!.GetType();
            var processedCount = (int)resultType.GetProperty("processed_count")!.GetValue(okResult.Value)!;
            Assert.Equal(0, processedCount);

            // Arrange - Add Purchase
            var purchase = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CourseId = courseId,
                PaymentProvider = "DIRECT",
                TransactionId = "TX_PAID_OK",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };
            await db.Purchases.AddAsync(purchase);
            await db.SaveChangesAsync();

            // Act - Sync after purchase
            result = await controller.SyncProgress(syncInput);

            // Assert - Should process successfully
            okResult = Assert.IsType<OkObjectResult>(result);
            resultType = okResult.Value!.GetType();
            processedCount = (int)resultType.GetProperty("processed_count")!.GetValue(okResult.Value)!;
            Assert.Equal(1, processedCount);

            // Verify db progress state
            var progress = await db.LeitnerProgresses.FirstOrDefaultAsync(p => p.UserId == userId && p.CardId == card.Id);
            Assert.NotNull(progress);
            Assert.Equal(2, progress.CurrentBox);

            // Verify event emission
            mockEventBus.Verify(e => e.PublishAsync(It.Is<CardReviewedEvent>(ev => 
                ev.UserId == userId && ev.CourseId == courseId && ev.CardNumber == 42 && ev.Box == 2)), Times.Once);
        }

        [Fact]
        public async Task SyncProgress_ConflictResolution_NewerTimestampShouldWin()
        {
            // Arrange
            var db = GetDatabaseContext();
            var userId = Guid.NewGuid();
            var courseId = Guid.NewGuid();

            var course = new Course { Id = courseId, Title = "Free Course", Price = 0.00m, IsPublished = true };
            var card = new Card { Id = Guid.NewGuid(), CourseId = courseId, CardNumber = 10, QuestionText = "Q", AnswerText = "A" };

            // Initial older progress in DB
            var existingProgress = new LeitnerProgress
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CardId = card.Id,
                CurrentBox = 3,
                LastReviewedAt = new DateTime(2026, 6, 21, 10, 0, 0, DateTimeKind.Utc),
                NextReviewDue = new DateTime(2026, 6, 28, 10, 0, 0, DateTimeKind.Utc)
            };

            await db.Courses.AddAsync(course);
            await db.Cards.AddAsync(card);
            await db.LeitnerProgresses.AddAsync(existingProgress);
            await db.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var controller = new StatisticsController(db, mockEventBus.Object);

            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act 1: Sync with OLDER timestamp delta (e.g. 9:00 UTC)
            var syncInputOlder = new ProgressSyncInput
            {
                SyncTime = DateTime.UtcNow,
                ProgressDeltas = new List<ProgressDeltaInput>
                {
                    new ProgressDeltaInput
                    {
                        CourseId = courseId,
                        CardNumber = 10,
                        CurrentBox = 1,
                        LastReviewedAt = new DateTime(2026, 6, 21, 9, 0, 0, DateTimeKind.Utc),
                        NextReviewDue = new DateTime(2026, 6, 21, 9, 0, 0, DateTimeKind.Utc),
                        Trigger = "REVIEW_INCORRECT"
                    }
                }
            };
            var result = await controller.SyncProgress(syncInputOlder);
            var okResult = Assert.IsType<OkObjectResult>(result);
            var resultType = okResult.Value!.GetType();
            var processedCount = (int)resultType.GetProperty("processed_count")!.GetValue(okResult.Value)!;
            Assert.Equal(0, processedCount); // Skipped because it is older

            // Act 2: Sync with NEWER timestamp delta (e.g. 11:00 UTC)
            var syncInputNewer = new ProgressSyncInput
            {
                SyncTime = DateTime.UtcNow,
                ProgressDeltas = new List<ProgressDeltaInput>
                {
                    new ProgressDeltaInput
                    {
                        CourseId = courseId,
                        CardNumber = 10,
                        CurrentBox = 4,
                        LastReviewedAt = new DateTime(2026, 6, 21, 11, 0, 0, DateTimeKind.Utc),
                        NextReviewDue = new DateTime(2026, 7, 7, 11, 0, 0, DateTimeKind.Utc),
                        Trigger = "REVIEW_CORRECT"
                    }
                }
            };
            result = await controller.SyncProgress(syncInputNewer);
            okResult = Assert.IsType<OkObjectResult>(result);
            resultType = okResult.Value!.GetType();
            processedCount = (int)resultType.GetProperty("processed_count")!.GetValue(okResult.Value)!;
            Assert.Equal(1, processedCount); // Allowed because it is newer

            var updatedProgress = await db.LeitnerProgresses.FirstOrDefaultAsync(p => p.UserId == userId && p.CardId == card.Id);
            Assert.NotNull(updatedProgress);
            Assert.Equal(4, updatedProgress.CurrentBox);
        }
    }
}
