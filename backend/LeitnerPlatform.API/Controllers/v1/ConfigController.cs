using System;
using System.Collections.Generic;
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
            
            string apiServer = configs.TryGetValue("api_server", out var apiVal) ? apiVal : "http://localhost:5000/api/v1";
            string contentServer = configs.TryGetValue("content_server", out var contentVal) ? contentVal : "http://localhost:5000/api/v1";
            string bannerServer = configs.TryGetValue("banner_server", out var bannerVal) ? bannerVal : "http://localhost:5000/api/v1";

            bool enableAiTutor = configs.TryGetValue("enable_ai_tutor", out var aiVal) && bool.TryParse(aiVal, out var aiBool) && aiBool;
            bool enableCustomThemes = !configs.TryGetValue("enable_custom_themes", out var themeVal) || !bool.TryParse(themeVal, out var themeBool) || themeBool;
            bool enableSearchV2 = !configs.TryGetValue("enable_search_v2", out var searchVal) || !bool.TryParse(searchVal, out var searchBool) || searchBool;

            int rotationInterval = configs.TryGetValue("rotation_interval_seconds", out var rotVal) && int.TryParse(rotVal, out var rotInt) ? rotInt : 4;
            int maxBannerCount = configs.TryGetValue("max_banner_count", out var maxVal) && int.TryParse(maxVal, out var maxInt) ? maxInt : 5;

            return Ok(new
            {
                maintenance_mode = maintenanceMode,
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
                    enable_search_v2 = enableSearchV2
                },
                banner_configs = new
                {
                    rotation_interval_seconds = rotationInterval,
                    max_banner_count = maxBannerCount
                },
                announcements = announcements,
                banners = banners
            });
        }
    }
}
