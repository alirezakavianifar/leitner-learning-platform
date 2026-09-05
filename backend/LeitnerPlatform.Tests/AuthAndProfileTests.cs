using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Moq;
using Xunit;
using LeitnerPlatform.API.Controllers.v1;
using LeitnerPlatform.API.Services;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;
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

        [Fact]
        public async Task AuthController_RefreshToken_ShouldGenerateNewTokenPair_WhenValid()
        {
            // Arrange
            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection().Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var userId = Guid.NewGuid();
            var user = new User
            {
                Id = userId,
                Username = "active_user",
                MobileNumber = "+989123456789",
                CreatedAt = DateTime.UtcNow
            };

            var validRefreshToken = "sample_refresh_token_123";
            memoryCache.Set($"refresh_token:{validRefreshToken}", userId.ToString(), TimeSpan.FromDays(30));
            mockUserRepo.Setup(r => r.GetByIdAsync(userId)).ReturnsAsync(user);

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache);

            // Act
            var result = await controller.RefreshToken(new RefreshTokenInput { RefreshToken = validRefreshToken });

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);

            var type = okResult.Value.GetType();
            var successVal = type.GetProperty("success")?.GetValue(okResult.Value);
            var tokenVal = type.GetProperty("token")?.GetValue(okResult.Value) as string;
            var newRefreshTokenVal = type.GetProperty("refresh_token")?.GetValue(okResult.Value) as string;

            Assert.Equal(true, successVal);
            Assert.False(string.IsNullOrEmpty(tokenVal));
            Assert.False(string.IsNullOrEmpty(newRefreshTokenVal));
            Assert.NotEqual(validRefreshToken, newRefreshTokenVal);

            // Old token should be deleted from cache
            Assert.False(memoryCache.TryGetValue($"refresh_token:{validRefreshToken}", out _));
            // New token should be in cache
            Assert.True(memoryCache.TryGetValue($"refresh_token:{newRefreshTokenVal}", out var cachedUserId));
            Assert.Equal(userId.ToString(), cachedUserId);
        }

        [Fact]
        public async Task AuthController_RefreshToken_ShouldReturnUnauthorized_WhenInvalid()
        {
            // Arrange
            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection().Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache);

            // Act
            var result = await controller.RefreshToken(new RefreshTokenInput { RefreshToken = "invalid_token" });

            // Assert
            Assert.IsType<UnauthorizedObjectResult>(result);
        }

        [Fact]
        public async Task AuthController_CustomTokenLifetimes_ShouldRespectConfigValues()
        {
            // Arrange
            var options = new Microsoft.EntityFrameworkCore.DbContextOptionsBuilder<LeitnerPlatform.Data.LeitnerDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            using var dbContext = new LeitnerPlatform.Data.LeitnerDbContext(options);

            // Configure 15 minutes JWT and 7 days refresh token
            await dbContext.SystemConfigs.AddAsync(new SystemConfig { Key = "jwt_lifetime_value", Value = "15" });
            await dbContext.SystemConfigs.AddAsync(new SystemConfig { Key = "jwt_lifetime_unit", Value = "minutes" });
            await dbContext.SystemConfigs.AddAsync(new SystemConfig { Key = "refresh_token_lifetime_value", Value = "7" });
            await dbContext.SystemConfigs.AddAsync(new SystemConfig { Key = "refresh_token_lifetime_unit", Value = "days" });
            await dbContext.SaveChangesAsync();

            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection().Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var userId = Guid.NewGuid();
            var user = new User
            {
                Id = userId,
                Username = "active_user",
                MobileNumber = "+989123456789",
                CreatedAt = DateTime.UtcNow
            };

            var validRefreshToken = "custom_refresh_token_456";
            memoryCache.Set($"refresh_token:{validRefreshToken}", userId.ToString(), TimeSpan.FromDays(7));
            mockUserRepo.Setup(r => r.GetByIdAsync(userId)).ReturnsAsync(user);

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache,
                null,
                dbContext);

            // Act
            var result = await controller.RefreshToken(new RefreshTokenInput { RefreshToken = validRefreshToken });

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var type = okResult.Value!.GetType();
            var tokenStr = type.GetProperty("token")?.GetValue(okResult.Value) as string;
            Assert.False(string.IsNullOrEmpty(tokenStr));

            var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
            var jwt = handler.ReadJwtToken(tokenStr);

            // Verify JWT expiry is around 15 minutes from now (allowing a 1-minute delta)
            var expectedExpiry = DateTime.UtcNow.AddMinutes(15);
            var diff = Math.Abs((jwt.ValidTo - expectedExpiry).TotalSeconds);
            Assert.True(diff < 60, $"JWT validity difference {diff}s is unexpectedly high.");
        }

        [Fact]
        public async Task UserController_GetProfile_ShouldReturnProfilePictureUrl()
        {
            var mockRepo = new Mock<IUserRepository>();
            var userId = Guid.NewGuid();
            var testUser = new User
            {
                Id = userId,
                Username = "avatar_user",
                MobileNumber = "+989129999999",
                ProfilePictureUrl = "/uploads/avatars/avatar_test.png",
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

            var result = await controller.GetProfile();
            var okResult = Assert.IsType<OkObjectResult>(result);
            var type = okResult.Value!.GetType();
            var urlVal = type.GetProperty("profile_picture_url")?.GetValue(okResult.Value) as string;

            Assert.Equal("/uploads/avatars/avatar_test.png", urlVal);
        }

        [Fact]
        public async Task UserController_UploadAvatar_InvalidExtension_ShouldReturnBadRequest()
        {
            var mockRepo = new Mock<IUserRepository>();
            var userId = Guid.NewGuid();
            var controller = new UserController(mockRepo.Object);
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim("sub", userId.ToString())
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var stream = new System.IO.MemoryStream(new byte[] { 1, 2, 3 });
            var file = new FormFile(stream, 0, 3, "file", "test.exe");

            var result = await controller.UploadAvatar(file);
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.NotNull(badRequest.Value);
        }

        [Fact]
        public async Task UserController_UploadAvatar_ValidImage_ShouldSaveAndReturnUrl()
        {
            var mockRepo = new Mock<IUserRepository>();
            var userId = Guid.NewGuid();
            var testUser = new User
            {
                Id = userId,
                Username = "upload_user",
                MobileNumber = "+989121111111",
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

            var stream = new System.IO.MemoryStream(new byte[] { 0x89, 0x50, 0x4E, 0x47 });
            var file = new FormFile(stream, 0, 4, "file", "photo.png");

            var result = await controller.UploadAvatar(file);
            var okResult = Assert.IsType<OkObjectResult>(result);
            var type = okResult.Value!.GetType();
            var urlVal = type.GetProperty("profile_picture_url")?.GetValue(okResult.Value) as string;

            Assert.NotNull(urlVal);
            Assert.StartsWith("/uploads/avatars/avatar_", urlVal);
            Assert.EndsWith(".png", urlVal);
            Assert.Equal(urlVal, testUser.ProfilePictureUrl);
            mockRepo.Verify(r => r.UpdateAsync(testUser), Times.Once);
            mockRepo.Verify(r => r.SaveChangesAsync(), Times.Once);
        }

        [Fact]
        public async Task UserController_DeleteAvatar_ShouldClearUrl()
        {
            var mockRepo = new Mock<IUserRepository>();
            var userId = Guid.NewGuid();
            var testUser = new User
            {
                Id = userId,
                Username = "delete_user",
                MobileNumber = "+989122222222",
                ProfilePictureUrl = "/uploads/avatars/avatar_old.png",
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

            var result = await controller.DeleteAvatar();
            var okResult = Assert.IsType<OkObjectResult>(result);

            Assert.Null(testUser.ProfilePictureUrl);
            mockRepo.Verify(r => r.UpdateAsync(testUser), Times.Once);
            mockRepo.Verify(r => r.SaveChangesAsync(), Times.Once);
        }

        [Fact]
        public async Task AuthController_VerifyOtp_BypassCode12345_ShouldFailWithInvalidOtp()
        {
            // Arrange
            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
            {
                { "ADMIN_ALLOWED_MOBILE_NUMBERS", "09121111111" }
            }).Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            // Legitimate OTP is 987654 in cache
            memoryCache.Set("otp:+989120001234", "987654");

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache);

            var input = new OtpVerifyInput
            {
                MobileNumber = "09120001234",
                OtpCode = "12345" // Hardcoded bypass attempt
            };

            // Act
            var result = await controller.VerifyOtp(input);

            // Assert: Must return 401 Unauthorized with INVALID_OTP error code
            var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
            var value = unauthorizedResult.Value!;
            var errorCode = (string)value.GetType().GetProperty("error_code")!.GetValue(value)!;
            Assert.Equal("INVALID_OTP", errorCode);
        }

        [Fact]
        public async Task AuthController_VerifyOtp_AdminLogin_NonWhitelistedMobile_ShouldReturnUnauthorizedAdminMobile()
        {
            // Arrange
            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
            {
                { "ADMIN_ALLOWED_MOBILE_NUMBERS", "+989129999999,09129999999" },
                { "ADMIN_USERNAME", "admin" },
                { "ADMIN_PASSWORD", "AdminPass123!" }
            }).Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var attackerMobile = "09120000001";
            memoryCache.Set($"otp:+989120000001", "654321");

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache);

            var input = new OtpVerifyInput
            {
                MobileNumber = attackerMobile,
                OtpCode = "654321",
                IsAdminLogin = true,
                Username = "admin",
                Password = "AdminPass123!"
            };

            // Act
            var result = await controller.VerifyOtp(input);

            // Assert: Must reject with UNAUTHORIZED_ADMIN_MOBILE
            var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
            var value = unauthorizedResult.Value!;
            var errorCode = (string)value.GetType().GetProperty("error_code")!.GetValue(value)!;
            Assert.Equal("UNAUTHORIZED_ADMIN_MOBILE", errorCode);
        }

        [Fact]
        public async Task AuthController_VerifyOtp_AdminLogin_WhitelistedMobile_ShouldSucceedWithAdminRole()
        {
            // Arrange
            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
            {
                { "ADMIN_ALLOWED_MOBILE_NUMBERS", "+989129999999,09129999999" },
                { "ADMIN_USERNAME", "admin" },
                { "ADMIN_PASSWORD", "AdminPass123!" }
            }).Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var ownerMobile = "09129999999";
            var normalizedMobile = "+989129999999";
            memoryCache.Set($"otp:{normalizedMobile}", "654321");

            var existingUser = new User
            {
                Id = Guid.NewGuid(),
                Username = "admin",
                MobileNumber = normalizedMobile,
                IsAdmin = true,
                CreatedAt = DateTime.UtcNow
            };
            mockUserRepo.Setup(r => r.GetByMobileNumberAsync(normalizedMobile)).ReturnsAsync(existingUser);

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache);

            var input = new OtpVerifyInput
            {
                MobileNumber = ownerMobile,
                OtpCode = "654321",
                IsAdminLogin = true,
                Username = "admin",
                Password = "AdminPass123!"
            };

            // Act
            var result = await controller.VerifyOtp(input);

            // Assert: Succeeded
            var okResult = Assert.IsType<OkObjectResult>(result);
            var value = okResult.Value!;
            var success = (bool)value.GetType().GetProperty("success")!.GetValue(value)!;
            var role = (string)value.GetType().GetProperty("role")!.GetValue(value)!;
            Assert.True(success);
            Assert.Equal("Admin", role);
        }

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
        public async Task AuthController_VerifyOtp_EmergencyBypass_WhenEnabled_ShouldSucceedFor09120000000()
        {
            // Arrange
            var db = GetDatabaseContext();
            await db.SystemConfigs.AddAsync(new SystemConfig { Key = "admin_emergency_bypass_enabled", Value = "true" });
            await db.SaveChangesAsync();

            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
            {
                { "ADMIN_USERNAME", "admin" },
                { "ADMIN_PASSWORD", "AdminPass123!" }
            }).Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache,
                dbContext: db);

            var input = new OtpVerifyInput
            {
                MobileNumber = "09120000000",
                OtpCode = "12345",
                IsAdminLogin = true,
                Username = "admin",
                Password = "AdminPass123!"
            };

            // Act
            var result = await controller.VerifyOtp(input);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var value = okResult.Value!;
            var success = (bool)value.GetType().GetProperty("success")!.GetValue(value)!;
            var role = (string)value.GetType().GetProperty("role")!.GetValue(value)!;
            Assert.True(success);
            Assert.Equal("Admin", role);
        }

        [Fact]
        public async Task AuthController_VerifyOtp_EmergencyBypass_WhenDisabled_ShouldFailWithInvalidOtp()
        {
            // Arrange
            var db = GetDatabaseContext();
            await db.SystemConfigs.AddAsync(new SystemConfig { Key = "admin_emergency_bypass_enabled", Value = "false" });
            await db.SaveChangesAsync();

            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
            {
                { "ADMIN_USERNAME", "admin" },
                { "ADMIN_PASSWORD", "AdminPass123!" }
            }).Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache,
                dbContext: db);

            var input = new OtpVerifyInput
            {
                MobileNumber = "09120000000",
                OtpCode = "12345",
                IsAdminLogin = true,
                Username = "admin",
                Password = "AdminPass123!"
            };

            // Act
            var result = await controller.VerifyOtp(input);

            // Assert
            var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
            var value = unauthorizedResult.Value!;
            var errorCode = (string)value.GetType().GetProperty("error_code")!.GetValue(value)!;
            Assert.Equal("INVALID_OTP", errorCode);
        }

        [Fact]
        public async Task AuthController_VerifyOtp_DynamicDatabaseWhitelist_ShouldAuthorizeDatabaseConfiguredMobile()
        {
            // Arrange
            var db = GetDatabaseContext();
            await db.SystemConfigs.AddAsync(new SystemConfig { Key = "admin_allowed_mobile_numbers", Value = "09127778899" });
            await db.SystemConfigs.AddAsync(new SystemConfig { Key = "admin_emergency_bypass_enabled", Value = "false" });
            await db.SaveChangesAsync();

            var mockUserRepo = new Mock<IUserRepository>();
            var mockSms = new Mock<ISmsService>();
            var mockCaptcha = new Mock<ICaptchaService>();
            var mockEventBus = new Mock<IEventBus>();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
            {
                { "ADMIN_USERNAME", "admin" },
                { "ADMIN_PASSWORD", "AdminPass123!" }
            }).Build();
            var memoryCache = new MemoryCache(new MemoryCacheOptions());

            var normalizedMobile = "+989127778899";
            memoryCache.Set($"otp:{normalizedMobile}", "88888");

            var controller = new AuthController(
                mockUserRepo.Object,
                mockSms.Object,
                mockCaptcha.Object,
                mockEventBus.Object,
                config,
                memoryCache,
                dbContext: db);

            var input = new OtpVerifyInput
            {
                MobileNumber = "09127778899",
                OtpCode = "88888",
                IsAdminLogin = true,
                Username = "admin",
                Password = "AdminPass123!"
            };

            // Act
            var result = await controller.VerifyOtp(input);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var value = okResult.Value!;
            var success = (bool)value.GetType().GetProperty("success")!.GetValue(value)!;
            var role = (string)value.GetType().GetProperty("role")!.GetValue(value)!;
            Assert.True(success);
            Assert.Equal("Admin", role);
        }
    }
}
