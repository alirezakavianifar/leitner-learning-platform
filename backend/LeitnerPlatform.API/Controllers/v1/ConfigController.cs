using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Data;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.API.Controllers.v1
{
    [ApiController]
    [Route("api/v1")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class ConfigController : ControllerBase
    {
        private readonly LeitnerDbContext _context;

        public ConfigController(LeitnerDbContext context)
        {
            _context = context;
        }

        [AllowAnonymous]
        [HttpGet("config/features")]
        public async Task<IActionResult> GetConfigFeatures()
        {
            var configs = await _context.SystemConfigs.ToDictionaryAsync(c => c.Key, c => c.Value);

            // Fetch active banners and announcements to include them
            var banners = await _context.Banners
                .Where(b => b.IsActive)
                .OrderBy(b => b.DisplayOrder)
                .Select(b => new
                {
                    id = b.Id.ToString(),
                    image_url = b.ImageUrl,
                    link_url = b.LinkUrl,
                    display_order = b.DisplayOrder
                })
                .ToListAsync();

            var announcements = await _context.Announcements
                .OrderByDescending(a => a.PublishedAt)
                .Select(a => new
                {
                    id = a.Id.ToString(),
                    title = a.Title,
                    content = a.Content,
                    published_at = a.PublishedAt
                })
                .ToListAsync();

            // Extract values with sensible defaults
            bool maintenanceMode = configs.TryGetValue("maintenance_mode", out var mVal) && bool.TryParse(mVal, out var mBool) && mBool;
            
            var request = HttpContext?.Request;
            string defaultServer = request != null && request.Host.HasValue 
                ? $"{request.Scheme}://{request.Host}/api/v1" 
                : "http://localhost:5217/api/v1";

            string apiServer = configs.TryGetValue("api_server", out var apiVal) && !string.IsNullOrWhiteSpace(apiVal) ? apiVal : defaultServer;
            string contentServer = configs.TryGetValue("content_server", out var contentVal) && !string.IsNullOrWhiteSpace(contentVal) ? contentVal : defaultServer;
            string bannerServer = configs.TryGetValue("banner_server", out var bannerVal) && !string.IsNullOrWhiteSpace(bannerVal) ? bannerVal : defaultServer;

            var hostStr = request?.Host.Host;
            bool isRemoteClient = !string.IsNullOrEmpty(hostStr) &&
                                  !hostStr.Equals("localhost", StringComparison.OrdinalIgnoreCase) &&
                                  !hostStr.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase) &&
                                  !hostStr.Equals("10.0.2.2", StringComparison.OrdinalIgnoreCase);

            // If the incoming request is hitting a remote production host, don't serve internal loopback addresses
            if (isRemoteClient)
            {
                if (apiServer.Contains("10.0.2.2") || apiServer.Contains("localhost") || apiServer.Contains("127.0.0.1"))
                {
                    apiServer = defaultServer;
                }
                if (contentServer.Contains("10.0.2.2") || contentServer.Contains("localhost") || contentServer.Contains("127.0.0.1"))
                {
                    contentServer = defaultServer;
                }
                if (bannerServer.Contains("10.0.2.2") || bannerServer.Contains("localhost") || bannerServer.Contains("127.0.0.1"))
                {
                    bannerServer = defaultServer;
                }
            }
            else if (Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Development")
            {
                apiServer = apiServer.Replace("8080", "5217");
                contentServer = contentServer.Replace("8080", "5217");
                bannerServer = bannerServer.Replace("8080", "5217");
            }

            bool enableAiTutor = configs.TryGetValue("enable_ai_tutor", out var aiVal) && bool.TryParse(aiVal, out var aiBool) && aiBool;
            bool enableCustomThemes = !configs.TryGetValue("enable_custom_themes", out var themeVal) || !bool.TryParse(themeVal, out var themeBool) || themeBool;
            bool enableSearchV2 = !configs.TryGetValue("enable_search_v2", out var searchVal) || !bool.TryParse(searchVal, out var searchBool) || searchBool;
            bool enableGamifiedLayout = !configs.TryGetValue("enable_gamified_layout", out var gVal) || !bool.TryParse(gVal, out var gBool) || gBool;
            bool enableScreenshotProtection = !configs.TryGetValue("enable_screenshot_protection", out var screenVal) || !bool.TryParse(screenVal, out var screenBool) || screenBool;

            int rotationInterval = configs.TryGetValue("rotation_interval_seconds", out var rotVal) && int.TryParse(rotVal, out var rotInt) ? rotInt : 4;
            int maxBannerCount = configs.TryGetValue("max_banner_count", out var maxVal) && int.TryParse(maxVal, out var maxInt) ? maxInt : 5;
            string cardNavIconStyle = configs.TryGetValue("card_nav_icon_style", out var iconStyleVal) && !string.IsNullOrWhiteSpace(iconStyleVal) ? iconStyleVal : "chevron";
            double globalIconScale = configs.TryGetValue("global_icon_scale", out var gisVal) && double.TryParse(gisVal, NumberStyles.Any, CultureInfo.InvariantCulture, out var gisDbl) ? gisDbl : 1.0;
            int cardNavIconSize = configs.TryGetValue("card_nav_icon_size", out var cnsVal) && int.TryParse(cnsVal, out var cnsInt) ? cnsInt : 20;
            int bottomNavIconSize = configs.TryGetValue("bottom_nav_icon_size", out var bnsVal) && int.TryParse(bnsVal, out var bnsInt) ? bnsInt : 26;
            int appBarIconSize = configs.TryGetValue("app_bar_icon_size", out var absVal) && int.TryParse(absVal, out var absInt) ? absInt : 24;
            int appLogoSize = configs.TryGetValue("app_logo_size", out var alsVal) && int.TryParse(alsVal, out var alsInt) ? alsInt : 110;
            string appLogoUrl = configs.TryGetValue("app_logo_url", out var aluVal) && !string.IsNullOrWhiteSpace(aluVal) ? aluVal : "";

            int jwtLifetimeValue = configs.TryGetValue("jwt_lifetime_value", out var jwtVal) && int.TryParse(jwtVal, out var jv) ? jv : 1;
            string jwtLifetimeUnit = configs.TryGetValue("jwt_lifetime_unit", out var jwtUnit) ? jwtUnit : "days";
            int refreshTokenLifetimeValue = configs.TryGetValue("refresh_token_lifetime_value", out var refVal) && int.TryParse(refVal, out var rv) ? rv : 30;
            string refreshTokenLifetimeUnit = configs.TryGetValue("refresh_token_lifetime_unit", out var refUnit) ? refUnit : "days";
            bool enableAutoTokenRefresh = !configs.TryGetValue("enable_auto_token_refresh", out var autoRefVal) || !bool.TryParse(autoRefVal, out var autoRefBool) || autoRefBool;

            int leitnerBox2Interval = configs.TryGetValue("leitner_box2_interval", out var b2Val) && int.TryParse(b2Val, out var b2Int) ? b2Int : 3;
            int leitnerBox3Interval = configs.TryGetValue("leitner_box3_interval", out var b3Val) && int.TryParse(b3Val, out var b3Int) ? b3Int : 7;
            int leitnerBox4Interval = configs.TryGetValue("leitner_box4_interval", out var b4Val) && int.TryParse(b4Val, out var b4Int) ? b4Int : 16;
            int leitnerBox5Interval = configs.TryGetValue("leitner_box5_interval", out var b5Val) && int.TryParse(b5Val, out var b5Int) ? b5Int : 31;
            string leitnerIntervalUnit = configs.TryGetValue("leitner_interval_unit", out var unitVal) && !string.IsNullOrWhiteSpace(unitVal) ? unitVal : "days";

            string telegramUrl = configs.TryGetValue("telegram_url", out var tgVal) && !string.IsNullOrWhiteSpace(tgVal) ? tgVal : "https://t.me/RightlearnApp";
            string baleUrl = configs.TryGetValue("bale_url", out var baleVal) && !string.IsNullOrWhiteSpace(baleVal) ? baleVal : "https://ble.ir/rightlearnapp";
            string eitaaUrl = configs.TryGetValue("eitaa_url", out var eitaaVal) && !string.IsNullOrWhiteSpace(eitaaVal) ? eitaaVal : "https://eitaa.com/RightLearnApp";
            string supportUrl = configs.TryGetValue("support_url", out var supVal) && !string.IsNullOrWhiteSpace(supVal) ? supVal : "https://t.me/RLAppSupport";
            string supportId = configs.TryGetValue("support_id", out var supIdVal) && !string.IsNullOrWhiteSpace(supIdVal) ? supIdVal : "@RLAppSupport";

            return Ok(new
            {
                maintenance_mode = maintenanceMode,
                card_nav_icon_style = cardNavIconStyle,
                global_icon_scale = globalIconScale,
                card_nav_icon_size = cardNavIconSize,
                bottom_nav_icon_size = bottomNavIconSize,
                app_bar_icon_size = appBarIconSize,
                app_logo_size = appLogoSize,
                app_logo_url = appLogoUrl,
                endpoints = new
                {
                    api_server = apiServer,
                    content_server = contentServer,
                    banner_server = bannerServer
                },
                feature_flags = new
                {
                    enable_ai_tutor = enableAiTutor,
                    enable_custom_themes = enableCustomThemes,
                    enable_search_v2 = enableSearchV2,
                    enable_gamified_layout = enableGamifiedLayout,
                    enable_screenshot_protection = enableScreenshotProtection
                },
                app_styles = new
                {
                    card_nav_icon_style = cardNavIconStyle,
                    global_icon_scale = globalIconScale,
                    card_nav_icon_size = cardNavIconSize,
                    bottom_nav_icon_size = bottomNavIconSize,
                    app_bar_icon_size = appBarIconSize,
                    app_logo_size = appLogoSize,
                    app_logo_url = appLogoUrl
                },
                banner_configs = new
                {
                    rotation_interval_seconds = rotationInterval,
                    max_banner_count = maxBannerCount
                },
                leitner_configs = new
                {
                    box2_interval = leitnerBox2Interval,
                    box3_interval = leitnerBox3Interval,
                    box4_interval = leitnerBox4Interval,
                    box5_interval = leitnerBox5Interval,
                    interval_unit = leitnerIntervalUnit
                },
                auth_session_configs = new
                {
                    jwt_lifetime_value = jwtLifetimeValue,
                    jwt_lifetime_unit = jwtLifetimeUnit,
                    refresh_token_lifetime_value = refreshTokenLifetimeValue,
                    refresh_token_lifetime_unit = refreshTokenLifetimeUnit,
                    enable_auto_token_refresh = enableAutoTokenRefresh
                },
                social_links = new
                {
                    telegram_url = telegramUrl,
                    bale_url = baleUrl,
                    eitaa_url = eitaaUrl,
                    support_url = supportUrl,
                    support_id = supportId
                },
                announcements = announcements,
                banners = banners
            });
        }
    }
}
