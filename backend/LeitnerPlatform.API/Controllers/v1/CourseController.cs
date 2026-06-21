using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Data;
using LeitnerPlatform.Core.Entities;


namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize]
    [ApiController]
    [Route("api/v1/courses")]
    public class CourseController : ControllerBase
    {
        private readonly LeitnerDbContext _context;

        public CourseController(LeitnerDbContext context)
        {
            _context = context;
        }

        private Guid GetUserId()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                            ?? User.FindFirst("sub")?.Value;

            if (Guid.TryParse(userIdStr, out var id))
            {
                return id;
            }

            return Guid.Empty;
        }

        [HttpGet]
        public async Task<IActionResult> GetCourses()
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            // Get published courses
            var courses = await _context.Courses
                .Where(c => c.IsPublished)
                .OrderBy(c => c.Title)
                .ToListAsync();

            // Get user's completed purchases
            var completedPurchases = await _context.Purchases
                .Where(p => p.UserId == userId && p.Status == "COMPLETED")
                .Select(p => p.CourseId)
                .ToListAsync();

            var result = courses.Select(c =>
            {
                var isPurchased = c.Price == 0 || completedPurchases.Contains(c.Id);
                
                // Formulate absolute or relative download URL if purchased
                string? downloadUrl = null;
                if (isPurchased && !string.IsNullOrEmpty(c.DownloadUrl))
                {
                    var request = HttpContext.Request;
                    downloadUrl = $"{request.Scheme}://{request.Host}{c.DownloadUrl}";
                }

                return new
                {
                    id = c.Id,
                    title = c.Title,
                    description = c.Description,
                    category = c.Category,
                    difficulty = c.Difficulty,
                    price = c.Price,
                    card_count = c.CardCount,
                    is_purchased = isPurchased,
                    download_url = downloadUrl
                };
            });

            return Ok(result);
        }

        [HttpPost("{id}/download-token")]
        public async Task<IActionResult> RequestDownloadToken(Guid id)
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var course = await _context.Courses.FindAsync(id);
            if (course == null || !course.IsPublished)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            // Verify access (either course is free or user has purchased it)
            var hasAccess = course.Price == 0 || await _context.Purchases.AnyAsync(p => 
                p.UserId == userId && p.CourseId == id && p.Status == "COMPLETED");

            if (!hasAccess)
            {
                return StatusCode(403, new
                {
                    success = false,
                    error_code = "PURCHASE_REQUIRED",
                    message = "You must purchase this course before downloading."
                });
            }

            var request = HttpContext.Request;
            var absoluteDownloadUrl = $"{request.Scheme}://{request.Host}{course.DownloadUrl}";
            var tempToken = $"temp_sec_token_{Guid.NewGuid().ToString("N").Substring(0, 12)}";

            return Ok(new
            {
                success = true,
                download_url = absoluteDownloadUrl,
                token = tempToken,
                checksum = course.ChecksumSha256
            });
        }

        [HttpPost("reports")]
        public async Task<IActionResult> SubmitReport([FromBody] SubmitReportInput input)
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var course = await _context.Courses.FindAsync(input.CourseId);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            var report = new FlashcardReport
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CourseId = input.CourseId,
                CardNumber = input.CardNumber,
                ReportText = input.ReportText ?? string.Empty,
                SubmittedAt = DateTime.UtcNow,
                Status = "PENDING"
            };

            await _context.FlashcardReports.AddAsync(report);
            await _context.SaveChangesAsync();

            return Ok(new { success = true, message = "Report submitted successfully.", report_id = report.Id });
        }
    }

    public class SubmitReportInput
    {
        public Guid CourseId { get; set; }
        public int CardNumber { get; set; }
        public string ReportText { get; set; } = string.Empty;
    }
}

