using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Moq;
using Xunit;
using LeitnerPlatform.API.Controllers.v1;
using LeitnerPlatform.API.Services;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data.Services;

namespace LeitnerPlatform.Tests
{
    public class AuthAndProfileTests
    {
        [Fact]
        public async Task CaptchaService_ShouldGenerateAndValidateCaptcha()
        {
            // Arrange
            var memoryCache = new MemoryCache(new MemoryCacheOptions());
            var captchaService = new CaptchaService(memoryCache);

            // Act
            var (id, base64) = await captchaService.GenerateCaptchaAsync();

            // Assert
            Assert.False(string.IsNullOrEmpty(id));
            Assert.False(string.IsNullOrEmpty(base64));
            Assert.StartsWith("PHN2Zy", base64); // "PHN2Zy" is base64 for "<svg"

            // Validate answer (we don't know the random numbers generated, so let's extract the equation from the cache for testing)
            var expectedValueStr = memoryCache.Get<string>($"captcha:{id}");
            Assert.NotNull(expectedValueStr);

            var isValid = await captchaService.ValidateCaptchaAsync(id, expectedValueStr);
            Assert.True(isValid);
        }

        [Fact]
        public async Task UserController_GetProfile_ShouldReturnUserData()
        {
            // Arrange
            var mockRepo = new Mock<IUserRepository>();
            var userId = Guid.NewGuid();
            var testUser = new User
            {
                Id = userId,
                Username = "test_user",
                MobileNumber = "+989120000000",
                Interests = "Coding",
                EducationalField = "CS",
                EducationalLevel = "BSc",
                CreatedAt = DateTime.UtcNow
            };

            mockRepo.Setup(r => r.GetByIdAsync(userId)).ReturnsAsync(testUser);

            var controller = new UserController(mockRepo.Object);

            // Mock User context
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim("sub", userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            // Act
            var result = await controller.GetProfile();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);
            
            var type = okResult.Value.GetType();
            var idVal = type.GetProperty("id")?.GetValue(okResult.Value);
            var usernameVal = type.GetProperty("username")?.GetValue(okResult.Value);
            var mobileNumberVal = type.GetProperty("mobile_number")?.GetValue(okResult.Value);

            Assert.Equal(userId, idVal);
            Assert.Equal("test_user", usernameVal);
            Assert.Equal("+989120000000", mobileNumberVal);
        }

        [Fact]
        public async Task UserController_UpdateProfile_ShouldIgnoreMobileNumber()
        {
            // Arrange
            var mockRepo = new Mock<IUserRepository>();
            var userId = Guid.NewGuid();
            var testUser = new User
            {
                Id = userId,
                Username = "old_username",
                MobileNumber = "+989120000000", // Read-only
                Interests = "Old Interests",
                EducationalField = "Old Field",
                EducationalLevel = "Old Level",
                CreatedAt = DateTime.UtcNow
            };

            mockRepo.Setup(r => r.GetByIdAsync(userId)).ReturnsAsync(testUser);

            var controller = new UserController(mockRepo.Object);

            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim("sub", userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var updateInput = new ProfileUpdateInput
            {
                Username = "new_username",
                Interests = "New Interests",
                EducationalField = "New Field",
                EducationalLevel = "New Level"
            };

            // Act
            var result = await controller.UpdateProfile(updateInput);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            mockRepo.Verify(r => r.UpdateAsync(It.Is<User>(u =>
                u.Username == "new_username" &&
                u.MobileNumber == "+989120000000" && // Retained
                u.Interests == "New Interests" &&
                u.EducationalField == "New Field" &&
                u.EducationalLevel == "New Level"
            )), Times.Once);
        }

        [Fact]
        public async Task EventBus_ShouldDispatchUserRegisteredEvent_ToBackupService()
        {
            // Arrange
            var eventBus = new ChannelEventBus();
            var mockBackupService = new Mock<IBackupService>();
            var testUser = new User
            {
                Id = Guid.NewGuid(),
                Username = "new_registered_user",
                MobileNumber = "+989121111111"
            };

            var tcs = new TaskCompletionSource<bool>();

            eventBus.Subscribe<UserRegisteredEvent>(async @event =>
            {
                await mockBackupService.Object.ReplicateUserAsync(@event.User);
                tcs.SetResult(true);
            });

            // Act
            await eventBus.PublishAsync(new UserRegisteredEvent(testUser));

            // Run dispatcher loop manually for this test event
            var eventBusProcessor = new EventBusProcessor(eventBus);
            var cts = new CancellationTokenSource();
            _ = eventBusProcessor.StartAsync(cts.Token);

            // Wait for event handler execution
            var completedTask = await Task.WhenAny(tcs.Task, Task.Delay(2000));
            cts.Cancel();

            // Assert
            Assert.Equal(tcs.Task, completedTask);
            mockBackupService.Verify(b => b.ReplicateUserAsync(testUser), Times.Once);
        }
    }
}
