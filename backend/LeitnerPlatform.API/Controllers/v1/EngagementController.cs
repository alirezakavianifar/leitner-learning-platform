using System;
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
    [Authorize]
    [ApiController]
    [Route("api/v1")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class EngagementController : ControllerBase
    {
        private readonly LeitnerDbContext _context;

        public EngagementController(LeitnerDbContext context)
        {
            _context = context;
        }

        [AllowAnonymous]
        [HttpGet("banners")]
        public async Task<IActionResult> GetActiveBanners()
        {
            var activeBanners = await _context.Banners
                .Where(b => b.IsActive)
                .OrderBy(b => b.DisplayOrder)
                .ToListAsync();

            return Ok(activeBanners);
        }

        [AllowAnonymous]
        [HttpGet("announcements")]
        public async Task<IActionResult> GetAnnouncements()
        {
            var announcements = await _context.Announcements
                .OrderByDescending(a => a.PublishedAt)
                .ToListAsync();

            return Ok(announcements);
        }
    }
}
