using System;
using System.Linq;
using System.Security.Claims;
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
    [Route("api/v1/courses")]
    [EnableRateLimiting("GeneralRateLimit")]
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

        [AllowAnonymous]
        [HttpGet]
        public async Task<IActionResult> GetCourses()
        {
            var userId = GetUserId();
            var completedPurchases = new List<Guid>();

            if (userId != Guid.Empty)
            {
                // Get user's completed purchases first, so archived-but-purchased courses can
                // still be included below (buyers keep access even after a course is archived).
                completedPurchases = await _context.Purchases
                    .Where(p => p.UserId == userId && p.Status == "COMPLETED")
                    .Select(p => p.CourseId)
                    .ToListAsync();
            }

            // Catalog = published, non-archived courses (visible to everyone), plus any
            // course this user has purchased even if it has since been archived/unpublished.
            var courses = await _context.Courses
                .Where(c => (c.IsPublished && !c.IsArchived) || completedPurchases.Contains(c.Id))
                .OrderBy(c => c.Title)
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
                    image_url = c.ImageUrl,
                    is_purchased = isPurchased,
                    download_url = downloadUrl,
                    version = c.Version,
                    checksum_sha256 = c.ChecksumSha256,
                    updated_at = c.UpdatedAt,
                    is_critical_update = c.IsCriticalUpdate,
                    is_archived = c.IsArchived
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
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            // Verify access (either course is free or user has purchased it). Purchasers keep
            // download access even if the course was later archived/unpublished; non-purchasers
            // cannot access an unpublished or archived course at all.
            var hasPurchase = await _context.Purchases.AnyAsync(p =>
                p.UserId == userId && p.CourseId == id && p.Status == "COMPLETED");
            var hasAccess = hasPurchase || (course.IsPublished && !course.IsArchived && course.Price == 0);

            if (!course.IsPublished && !hasPurchase)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            if (!hasAccess)
            {
                return StatusCode(403, new
                {
                    success = false,
                    error_code = "PURCHASE_REQUIRED",
                    message = "You must purchase this course before downloading."
                });
            }

            // Guard against courses whose metadata exists (and is published) but whose
            // package file is missing/not yet uploaded to wwwroot - avoids the client
            // reaching 100% "download" of a broken/missing file with a confusing error.
            if (string.IsNullOrEmpty(course.DownloadUrl))
            {
                return StatusCode(503, new
                {
                    success = false,
                    error_code = "PACKAGE_NOT_AVAILABLE",
                    message = "This course's content package is not available yet. Please try again later."
                });
            }

            var relativePackagePath = course.DownloadUrl.TrimStart('/').Replace('/', System.IO.Path.DirectorySeparatorChar);
            var wwwrootPath = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot");
            var absolutePackagePath = System.IO.Path.Combine(wwwrootPath, relativePackagePath);
            var packageFileExists = System.IO.File.Exists(absolutePackagePath);

            string? checksum = course.ChecksumSha256;
            if (string.IsNullOrEmpty(checksum))
            {
                if (!packageFileExists)
                {
                    return StatusCode(503, new
                    {
                        success = false,
                        error_code = "PACKAGE_NOT_AVAILABLE",
                        message = "This course's content package has not been uploaded yet. Please try again later."
                    });
                }

                try
                {
                    using var sha256 = System.Security.Cryptography.SHA256.Create();
                    using var stream = System.IO.File.OpenRead(absolutePackagePath);
                    var hashBytes = await sha256.ComputeHashAsync(stream);
                    checksum = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();
                    course.ChecksumSha256 = checksum;
                    await _context.SaveChangesAsync();
                }
                catch
                {
                    // Fall back to existing value if disk read fails
                }
            }

            var request = HttpContext.Request;
            var absoluteDownloadUrl = $"{request.Scheme}://{request.Host}{course.DownloadUrl}";
            var tempToken = $"temp_sec_token_{Guid.NewGuid().ToString("N").Substring(0, 12)}";

            return Ok(new
            {
                success = true,
                download_url = absoluteDownloadUrl,
                token = tempToken,
                checksum = checksum,
                version = course.Version,
                is_critical_update = course.IsCriticalUpdate
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

            var user = await _context.Users.FindAsync(userId);
            var mobileNumber = user?.MobileNumber ?? string.Empty;

            var report = new FlashcardReport
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                UserMobileNumber = mobileNumber,
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

