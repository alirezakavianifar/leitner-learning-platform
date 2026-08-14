using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
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
    public class ConfigTests
    {
        private LeitnerDbContext GetInMemoryDbContext()
        {
            var options = new DbContextOptionsBuilder<LeitnerDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            return new LeitnerDbContext(options);
        }

        [Fact]
        public async Task ConfigController_GetConfigFeatures_ShouldReturnDefaults_WhenDbIsEmpty()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            var controller = new ConfigController(context);

            // Act
            var result = await controller.GetConfigFeatures();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);

            var type = okResult.Value!.GetType();
            var maintenanceMode = (bool?)type.GetProperty("maintenance_mode")?.GetValue(okResult.Value);
            var endpoints = type.GetProperty("endpoints")?.GetValue(okResult.Value);
            var featureFlags = type.GetProperty("feature_flags")?.GetValue(okResult.Value);
            var bannerConfigs = type.GetProperty("banner_configs")?.GetValue(okResult.Value);

            var cardNavIconStyle = (string?)type.GetProperty("card_nav_icon_style")?.GetValue(okResult.Value);

            Assert.False(maintenanceMode);
            Assert.Equal("chevron", cardNavIconStyle);
            Assert.NotNull(endpoints);
            Assert.NotNull(featureFlags);
            Assert.NotNull(bannerConfigs);

            var epType = endpoints.GetType();
            Assert.Equal("http://localhost:5217/api/v1", epType.GetProperty("api_server")?.GetValue(endpoints));

            var flagType = featureFlags.GetType();
            Assert.False((bool?)flagType.GetProperty("enable_ai_tutor")?.GetValue(featureFlags));
            Assert.True((bool?)flagType.GetProperty("enable_custom_themes")?.GetValue(featureFlags));
        }

        [Fact]
        public async Task ConfigController_GetConfigFeatures_ShouldReturnDbValues_WhenDbHasConfig()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            await context.SystemConfigs.AddRangeAsync(new List<SystemConfig>
            {
                new SystemConfig { Key = "maintenance_mode", Value = "true" },
                new SystemConfig { Key = "api_server", Value = "https://custom-api.com/v1" },
                new SystemConfig { Key = "enable_ai_tutor", Value = "true" },
                new SystemConfig { Key = "card_nav_icon_style", Value = "arrow" }
            });
            await context.SaveChangesAsync();

            var controller = new ConfigController(context);

            // Act
            var result = await controller.GetConfigFeatures();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var type = okResult.Value!.GetType();
            var maintenanceMode = (bool?)type.GetProperty("maintenance_mode")?.GetValue(okResult.Value);
            var cardNavIconStyle = (string?)type.GetProperty("card_nav_icon_style")?.GetValue(okResult.Value);
            var endpoints = type.GetProperty("endpoints")?.GetValue(okResult.Value);
            var featureFlags = type.GetProperty("feature_flags")?.GetValue(okResult.Value);

            Assert.True(maintenanceMode);
            Assert.Equal("arrow", cardNavIconStyle);
            Assert.NotNull(endpoints);
            Assert.NotNull(featureFlags);

            var epType = endpoints.GetType();
            Assert.Equal("https://custom-api.com/v1", epType.GetProperty("api_server")?.GetValue(endpoints));

            var flagType = featureFlags.GetType();
            Assert.True((bool?)flagType.GetProperty("enable_ai_tutor")?.GetValue(featureFlags));
        }

        [Fact]
        public async Task AdminController_GetSystemConfig_ShouldReturnAllConfigs()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            await context.SystemConfigs.AddAsync(new SystemConfig { Key = "test_key", Value = "test_val" });
            await context.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var mockAudit = new Mock<IAuditLogService>();
            var mockLogger = new Mock<ILogger<AdminController>>();
            var controller = new AdminController(context, mockEventBus.Object, mockAudit.Object, mockLogger.Object);

            // Act
            var result = await controller.GetSystemConfig();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var type = okResult.Value!.GetType();
            var success = (bool?)type.GetProperty("success")?.GetValue(okResult.Value);
            var configs = type.GetProperty("configs")?.GetValue(okResult.Value) as List<SystemConfig>;

            Assert.True(success);
            Assert.NotNull(configs);
            Assert.Single(configs);
            Assert.Equal("test_key", configs![0].Key);
            Assert.Equal("test_val", configs![0].Value);
        }

        [Fact]
        public async Task AdminController_UpdateSystemConfig_ShouldModifyDatabaseAndLogAudit()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            await context.SystemConfigs.AddAsync(new SystemConfig { Key = "maintenance_mode", Value = "false" });
            await context.SaveChangesAsync();

            var mockEventBus = new Mock<IEventBus>();
            var mockAudit = new Mock<IAuditLogService>();
            var mockLogger = new Mock<ILogger<AdminController>>();
            
            var controller = new AdminController(context, mockEventBus.Object, mockAudit.Object, mockLogger.Object);
            
            var claimsPrincipal = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, "admin_user")
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = claimsPrincipal }
            };

            var updateInput = new SystemConfigUpdateInput
            {
                Configs = new List<SystemConfigItemInput>
                {
                    new SystemConfigItemInput { Key = "maintenance_mode", Value = "true" },
                    new SystemConfigItemInput { Key = "new_flag", Value = "enabled" }
                }
            };

            // Act
            var result = await controller.UpdateSystemConfig(updateInput);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            
            var updatedConfig = await context.SystemConfigs.FindAsync("maintenance_mode");
            Assert.NotNull(updatedConfig);
            Assert.Equal("true", updatedConfig!.Value);

            var addedConfig = await context.SystemConfigs.FindAsync("new_flag");
            Assert.NotNull(addedConfig);
            Assert.Equal("enabled", addedConfig!.Value);

            mockAudit.Verify(a => a.LogActionAsync(
                "admin_user",
                "UPDATE_SYSTEM_CONFIG",
                "SystemSettings",
                It.IsAny<string>(),
                It.IsAny<string>()
            ), Times.Once);
        }
    }
}
