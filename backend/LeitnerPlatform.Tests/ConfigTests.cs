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
            var globalIconScale = (double?)type.GetProperty("global_icon_scale")?.GetValue(okResult.Value);
            var cardNavIconSize = (int?)type.GetProperty("card_nav_icon_size")?.GetValue(okResult.Value);
            var bottomNavIconSize = (int?)type.GetProperty("bottom_nav_icon_size")?.GetValue(okResult.Value);
            var appBarIconSize = (int?)type.GetProperty("app_bar_icon_size")?.GetValue(okResult.Value);
            var appLogoSize = (int?)type.GetProperty("app_logo_size")?.GetValue(okResult.Value);

            Assert.False(maintenanceMode);
            Assert.Equal("chevron", cardNavIconStyle);
            Assert.Equal(1.0, globalIconScale);
            Assert.Equal(20, cardNavIconSize);
            Assert.Equal(26, bottomNavIconSize);
            Assert.Equal(24, appBarIconSize);
            Assert.Equal(110, appLogoSize);
            Assert.NotNull(endpoints);
            Assert.NotNull(featureFlags);
            Assert.NotNull(bannerConfigs);

            var epType = endpoints.GetType();
            Assert.Equal("http://localhost:5217/api/v1", epType.GetProperty("api_server")?.GetValue(endpoints));

            var flagType = featureFlags.GetType();
            Assert.False((bool?)flagType.GetProperty("enable_ai_tutor")?.GetValue(featureFlags));
            Assert.True((bool?)flagType.GetProperty("enable_custom_themes")?.GetValue(featureFlags));
            Assert.True((bool?)flagType.GetProperty("enable_screenshot_protection")?.GetValue(featureFlags));

            var appStyles = type.GetProperty("app_styles")?.GetValue(okResult.Value);
            Assert.NotNull(appStyles);
            var styleType = appStyles.GetType();
            Assert.Equal("chevron", (string?)styleType.GetProperty("card_nav_icon_style")?.GetValue(appStyles));
            Assert.Equal(1.0, (double?)styleType.GetProperty("global_icon_scale")?.GetValue(appStyles));
            Assert.Equal(20, (int?)styleType.GetProperty("card_nav_icon_size")?.GetValue(appStyles));
            Assert.Equal(26, (int?)styleType.GetProperty("bottom_nav_icon_size")?.GetValue(appStyles));
            Assert.Equal(24, (int?)styleType.GetProperty("app_bar_icon_size")?.GetValue(appStyles));
            Assert.Equal(110, (int?)styleType.GetProperty("app_logo_size")?.GetValue(appStyles));

            var socialLinks = type.GetProperty("social_links")?.GetValue(okResult.Value);
            Assert.NotNull(socialLinks);
            var socialType = socialLinks.GetType();
            Assert.Equal("https://t.me/RightlearnApp", (string?)socialType.GetProperty("telegram_url")?.GetValue(socialLinks));
            Assert.Equal("https://ble.ir/rightlearnapp", (string?)socialType.GetProperty("bale_url")?.GetValue(socialLinks));
            Assert.Equal("https://eitaa.com/RightLearnApp", (string?)socialType.GetProperty("eitaa_url")?.GetValue(socialLinks));
            Assert.Equal("https://t.me/RLAppSupport", (string?)socialType.GetProperty("support_url")?.GetValue(socialLinks));
            Assert.Equal("@RLAppSupport", (string?)socialType.GetProperty("support_id")?.GetValue(socialLinks));
        }

        [Fact]
        public async Task ConfigController_GetConfigFeatures_ShouldReturnCustomValues_WhenDbHasEntries()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            await context.SystemConfigs.AddRangeAsync(new List<SystemConfig>
            {
                new SystemConfig { Key = "maintenance_mode", Value = "true" },
                new SystemConfig { Key = "api_server", Value = "https://custom-api.com/v1" },
                new SystemConfig { Key = "enable_ai_tutor", Value = "true" },
                new SystemConfig { Key = "enable_screenshot_protection", Value = "false" },
                new SystemConfig { Key = "card_nav_icon_style", Value = "arrow" },
                new SystemConfig { Key = "global_icon_scale", Value = "1.2" },
                new SystemConfig { Key = "card_nav_icon_size", Value = "28" },
                new SystemConfig { Key = "bottom_nav_icon_size", Value = "32" },
                new SystemConfig { Key = "app_bar_icon_size", Value = "22" },
                new SystemConfig { Key = "app_logo_size", Value = "140" },
                new SystemConfig { Key = "telegram_url", Value = "https://t.me/CustomChannel" },
                new SystemConfig { Key = "support_url", Value = "https://t.me/CustomSupport" },
                new SystemConfig { Key = "leitner_box2_interval", Value = "5" },
                new SystemConfig { Key = "leitner_box3_interval", Value = "10" },
                new SystemConfig { Key = "leitner_box4_interval", Value = "15" },
                new SystemConfig { Key = "leitner_box5_interval", Value = "20" },
                new SystemConfig { Key = "leitner_interval_unit", Value = "minutes" }
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
            var globalIconScale = (double?)type.GetProperty("global_icon_scale")?.GetValue(okResult.Value);
            var cardNavIconSize = (int?)type.GetProperty("card_nav_icon_size")?.GetValue(okResult.Value);
            var bottomNavIconSize = (int?)type.GetProperty("bottom_nav_icon_size")?.GetValue(okResult.Value);
            var appBarIconSize = (int?)type.GetProperty("app_bar_icon_size")?.GetValue(okResult.Value);
            var appLogoSize = (int?)type.GetProperty("app_logo_size")?.GetValue(okResult.Value);
            var endpoints = type.GetProperty("endpoints")?.GetValue(okResult.Value);
            var featureFlags = type.GetProperty("feature_flags")?.GetValue(okResult.Value);
            var socialLinks = type.GetProperty("social_links")?.GetValue(okResult.Value);
            var leitnerConfigs = type.GetProperty("leitner_configs")?.GetValue(okResult.Value);

            Assert.True(maintenanceMode);
            Assert.Equal("arrow", cardNavIconStyle);
            Assert.Equal(1.2, globalIconScale);
            Assert.Equal(28, cardNavIconSize);
            Assert.Equal(32, bottomNavIconSize);
            Assert.Equal(22, appBarIconSize);
            Assert.Equal(140, appLogoSize);
            Assert.NotNull(endpoints);
            Assert.NotNull(featureFlags);
            Assert.NotNull(socialLinks);
            Assert.NotNull(leitnerConfigs);

            var epType = endpoints.GetType();
            Assert.Equal("https://custom-api.com/v1", epType.GetProperty("api_server")?.GetValue(endpoints));

            var flagType = featureFlags.GetType();
            Assert.True((bool?)flagType.GetProperty("enable_ai_tutor")?.GetValue(featureFlags));
            Assert.False((bool?)flagType.GetProperty("enable_screenshot_protection")?.GetValue(featureFlags));

            var socialType = socialLinks.GetType();
            Assert.Equal("https://t.me/CustomChannel", (string?)socialType.GetProperty("telegram_url")?.GetValue(socialLinks));
            Assert.Equal("https://t.me/CustomSupport", (string?)socialType.GetProperty("support_url")?.GetValue(socialLinks));
            Assert.Equal("https://ble.ir/rightlearnapp", (string?)socialType.GetProperty("bale_url")?.GetValue(socialLinks));

            var leitnerType = leitnerConfigs.GetType();
            Assert.Equal(5, (int?)leitnerType.GetProperty("box2_interval")?.GetValue(leitnerConfigs));
            Assert.Equal(10, (int?)leitnerType.GetProperty("box3_interval")?.GetValue(leitnerConfigs));
            Assert.Equal(15, (int?)leitnerType.GetProperty("box4_interval")?.GetValue(leitnerConfigs));
            Assert.Equal(20, (int?)leitnerType.GetProperty("box5_interval")?.GetValue(leitnerConfigs));
            Assert.Equal("minutes", (string?)leitnerType.GetProperty("interval_unit")?.GetValue(leitnerConfigs));
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
