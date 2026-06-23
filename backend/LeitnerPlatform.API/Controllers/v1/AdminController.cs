using System;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;

namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize(Roles = "Admin")]
    [ApiController]
    [Route("api/v1/admin")]
    [EnableRateLimiting("AdminRateLimit")]
    public class AdminController : ControllerBase
    {
        private readonly LeitnerDbContext _context;
        private readonly IEventBus _eventBus;
        private readonly IAuditLogService _auditLogService;

        public AdminController(LeitnerDbContext context, IEventBus eventBus, IAuditLogService auditLogService)
        {
            _context = context;
            _eventBus = eventBus;
            _auditLogService = auditLogService;
        }

        // Helper to get active admin username
        private string GetAdminUsername()
        {
            return User.FindFirst(ClaimTypes.Name)?.Value ?? "unknown_admin";
        }

        #region Dashboard & Analytics

        [HttpGet("dashboard/stats")]
        public async Task<IActionResult> GetDashboardStats()
        {
            var usersCount = await _context.Users.CountAsync();
            var coursesCount = await _context.Courses.CountAsync();
            var purchasesCount = await _context.Purchases.CountAsync(p => p.Status == "COMPLETED");
            var pendingReportsCount = await _context.FlashcardReports.CountAsync(r => r.Status == "PENDING");
            var activeProgressCardsCount = await _context.LeitnerProgresses.CountAsync();

            return Ok(new
            {
                success = true,
                stats = new
                {
                    users_count = usersCount,
                    courses_count = coursesCount,
                    purchases_count = purchasesCount,
                    pending_reports_count = pendingReportsCount,
                    active_learning_cards = activeProgressCardsCount
                }
            });
        }

        #endregion

        #region User Management

        [HttpGet("users")]
        public async Task<IActionResult> GetUsers([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 15)
        {
            var query = _context.Users.AsQueryable();

            if (!string.IsNullOrEmpty(search))
            {
                var cleanSearch = search.Trim().ToLower();
                query = query.Where(u => u.Username.ToLower().Contains(cleanSearch) || u.MobileNumber.Contains(cleanSearch));
            }

            var totalUsers = await query.CountAsync();
            var users = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new
            {
                success = true,
                total_count = totalUsers,
                page = page,
                page_size = pageSize,
                users = users
            });
        }

        [HttpGet("users/{id}")]
        public async Task<IActionResult> GetUserById(Guid id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User not found." });
            }

            var purchases = await _context.Purchases
                .Where(p => p.UserId == id)
                .Join(_context.Courses, p => p.CourseId, c => c.Id, (p, c) => new
                {
                    purchase_id = p.Id,
                    course_id = c.Id,
                    course_title = c.Title,
                    status = p.Status,
                    purchased_at = p.PurchasedAt,
                    payment_provider = p.PaymentProvider
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                user = user,
                purchases = purchases
            });
        }

        [HttpPut("users/{id}")]
        public async Task<IActionResult> UpdateUser(Guid id, [FromBody] AdminUserUpdateInput input)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User not found." });
            }

            var beforeJson = JsonSerializer.Serialize(user);

            user.Username = input.Username ?? user.Username;
            user.Interests = input.Interests;
            user.EducationalField = input.EducationalField;
            user.EducationalLevel = input.EducationalLevel;
            user.IsAdmin = input.IsAdmin ?? user.IsAdmin;

            _context.Entry(user).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(user);
            await _auditLogService.LogActionAsync(GetAdminUsername(), "UPDATE_USER", $"User:{id}", beforeJson, afterJson);

            return Ok(new { success = true, message = "User profile updated successfully.", user });
        }

        #endregion

        #region Course Access & Purchases

        [HttpGet("purchases")]
        public async Task<IActionResult> GetPurchases([FromQuery] int page = 1, [FromQuery] int pageSize = 15)
        {
            var query = _context.Purchases
                .Join(_context.Users, p => p.UserId, u => u.Id, (p, u) => new { p, u })
                .Join(_context.Courses, pu => pu.p.CourseId, c => c.Id, (pu, c) => new
                {
                    purchase_id = pu.p.Id,
                    user_id = pu.u.Id,
                    username = pu.u.Username,
                    mobile_number = pu.u.MobileNumber,
                    course_id = c.Id,
                    course_title = c.Title,
                    payment_provider = pu.p.PaymentProvider,
                    transaction_id = pu.p.TransactionId,
                    status = pu.p.Status,
                    purchased_at = pu.p.PurchasedAt
                });

            var totalPurchases = await query.CountAsync();
            var purchases = await query
                .OrderByDescending(p => p.purchased_at)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new
            {
                success = true,
                total_count = totalPurchases,
                page = page,
                page_size = pageSize,
                purchases = purchases
            });
        }

        [HttpPatch("users/{userId}/courses/{courseId}")]
        public async Task<IActionResult> ToggleCourseAccess(Guid userId, Guid courseId, [FromBody] ToggleCourseAccessInput input)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User not found." });
            }

            var course = await _context.Courses.FindAsync(courseId);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            var purchase = await _context.Purchases.FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == courseId);
            string? beforeJson = purchase != null ? JsonSerializer.Serialize(purchase) : null;
            string? afterJson = null;

            if (input.GrantAccess)
            {
                if (purchase == null)
                {
                    purchase = new Purchase
                    {
                        Id = Guid.NewGuid(),
                        UserId = userId,
                        CourseId = courseId,
                        PaymentProvider = "DIRECT",
                        TransactionId = $"MANUAL_{Guid.NewGuid().ToString("N").Substring(0, 10).ToUpper()}",
                        Status = "COMPLETED",
                        PurchasedAt = DateTime.UtcNow
                    };
                    await _context.Purchases.AddAsync(purchase);
                }
                else
                {
                    purchase.Status = "COMPLETED";
                    _context.Entry(purchase).State = EntityState.Modified;
                }

                await _context.SaveChangesAsync();
                afterJson = JsonSerializer.Serialize(purchase);

                // Publish Event Bus payload (triggers S3 backup replication)
                await _eventBus.PublishAsync(new PurchaseCompletedEvent(purchase));

                await _auditLogService.LogActionAsync(
                    GetAdminUsername(),
                    "GRANT_COURSE_ACCESS",
                    $"User:{userId}|Course:{courseId}",
                    beforeJson,
                    afterJson
                );
            }
            else
            {
                if (purchase != null)
                {
                    purchase.Status = "REFUNDED";
                    _context.Entry(purchase).State = EntityState.Modified;
                    await _context.SaveChangesAsync();
                    afterJson = JsonSerializer.Serialize(purchase);

                    await _auditLogService.LogActionAsync(
                        GetAdminUsername(),
                        "REVOKE_COURSE_ACCESS",
                        $"User:{userId}|Course:{courseId}",
                        beforeJson,
                        afterJson
                    );
                }
            }

            return Ok(new { success = true, message = "Course access state toggled successfully." });
        }

        #endregion

        #region Flashcard Typo Reports

        [HttpGet("reports")]
        public async Task<IActionResult> GetReports([FromQuery] string? status)
        {
            var query = _context.FlashcardReports.AsQueryable();

            if (!string.IsNullOrEmpty(status))
            {
                query = query.Where(r => r.Status == status);
            }

            var reports = await query
                .Join(_context.Users, r => r.UserId, u => u.Id, (r, u) => new { r, u })
                .Join(_context.Courses, ru => ru.r.CourseId, c => c.Id, (ru, c) => new
                {
                    report_id = ru.r.Id,
                    user_id = ru.u.Id,
                    username = ru.u.Username,
                    mobile_number = ru.u.MobileNumber,
                    course_id = c.Id,
                    course_title = c.Title,
                    card_number = ru.r.CardNumber,
                    report_text = ru.r.ReportText,
                    submitted_at = ru.r.SubmittedAt,
                    status = ru.r.Status
                })
                .OrderByDescending(r => r.submitted_at)
                .ToListAsync();

            return Ok(reports);
        }

        [HttpPatch("reports/{id}")]
        public async Task<IActionResult> UpdateReportStatus(Guid id, [FromBody] UpdateReportStatusInput input)
        {
            var report = await _context.FlashcardReports.FindAsync(id);
            if (report == null)
            {
                return NotFound(new { success = false, message = "Report not found." });
            }

            var beforeJson = JsonSerializer.Serialize(report);
            report.Status = input.Status ?? report.Status;

            _context.Entry(report).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(report);
            await _auditLogService.LogActionAsync(GetAdminUsername(), "UPDATE_REPORT", $"Report:{id}", beforeJson, afterJson);

            return Ok(new { success = true, message = "Report status updated successfully.", report });
        }

        #endregion

        #region Announcements CRUD

        [HttpGet("announcements")]
        public async Task<IActionResult> GetAnnouncements()
        {
            var list = await _context.Announcements.OrderByDescending(a => a.PublishedAt).ToListAsync();
            return Ok(list);
        }

        [HttpPost("announcements")]
        public async Task<IActionResult> CreateAnnouncement([FromBody] AnnouncementInput input)
        {
            var announcement = new Announcement
            {
                Id = Guid.NewGuid(),
                Title = input.Title,
                Content = input.Content,
                PublishedAt = DateTime.UtcNow
            };

            await _context.Announcements.AddAsync(announcement);
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(announcement);
            await _auditLogService.LogActionAsync(GetAdminUsername(), "CREATE_ANNOUNCEMENT", $"Announcement:{announcement.Id}", null, afterJson);

            return Ok(new { success = true, announcement });
        }

        [HttpPut("announcements/{id}")]
        public async Task<IActionResult> UpdateAnnouncement(Guid id, [FromBody] AnnouncementInput input)
        {
            var announcement = await _context.Announcements.FindAsync(id);
            if (announcement == null)
            {
                return NotFound(new { success = false, message = "Announcement not found." });
            }

            var beforeJson = JsonSerializer.Serialize(announcement);
            announcement.Title = input.Title;
            announcement.Content = input.Content;

            _context.Entry(announcement).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(announcement);
            await _auditLogService.LogActionAsync(GetAdminUsername(), "UPDATE_ANNOUNCEMENT", $"Announcement:{id}", beforeJson, afterJson);

            return Ok(new { success = true, announcement });
        }

        [HttpDelete("announcements/{id}")]
        public async Task<IActionResult> DeleteAnnouncement(Guid id)
        {
            var announcement = await _context.Announcements.FindAsync(id);
            if (announcement == null)
            {
                return NotFound(new { success = false, message = "Announcement not found." });
            }

            var beforeJson = JsonSerializer.Serialize(announcement);
            _context.Announcements.Remove(announcement);
            await _context.SaveChangesAsync();

            await _auditLogService.LogActionAsync(GetAdminUsername(), "DELETE_ANNOUNCEMENT", $"Announcement:{id}", beforeJson, null);

            return Ok(new { success = true, message = "Announcement deleted successfully." });
        }

        #endregion

        #region Banners CRUD

        [HttpGet("banners")]
        public async Task<IActionResult> GetBanners()
        {
            var list = await _context.Banners.OrderBy(b => b.DisplayOrder).ToListAsync();
            return Ok(list);
        }

        [HttpPost("banners")]
        public async Task<IActionResult> CreateBanner([FromBody] BannerInput input)
        {
            var banner = new Banner
            {
                Id = Guid.NewGuid(),
                ImageUrl = input.ImageUrl,
                LinkUrl = input.LinkUrl,
                DisplayOrder = input.DisplayOrder,
                IsActive = input.IsActive ?? true
            };

            await _context.Banners.AddAsync(banner);
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(banner);
            await _auditLogService.LogActionAsync(GetAdminUsername(), "CREATE_BANNER", $"Banner:{banner.Id}", null, afterJson);

            return Ok(new { success = true, banner });
        }

        [HttpPut("banners/{id}")]
        public async Task<IActionResult> UpdateBanner(Guid id, [FromBody] BannerInput input)
        {
            var banner = await _context.Banners.FindAsync(id);
            if (banner == null)
            {
                return NotFound(new { success = false, message = "Banner not found." });
            }

            var beforeJson = JsonSerializer.Serialize(banner);
            banner.ImageUrl = input.ImageUrl;
            banner.LinkUrl = input.LinkUrl;
            banner.DisplayOrder = input.DisplayOrder;
            banner.IsActive = input.IsActive ?? banner.IsActive;

            _context.Entry(banner).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(banner);
            await _auditLogService.LogActionAsync(GetAdminUsername(), "UPDATE_BANNER", $"Banner:{id}", beforeJson, afterJson);

            return Ok(new { success = true, banner });
        }

        [HttpDelete("banners/{id}")]
        public async Task<IActionResult> DeleteBanner(Guid id)
        {
            var banner = await _context.Banners.FindAsync(id);
            if (banner == null)
            {
                return NotFound(new { success = false, message = "Banner not found." });
            }

            var beforeJson = JsonSerializer.Serialize(banner);
            _context.Banners.Remove(banner);
            await _context.SaveChangesAsync();

            await _auditLogService.LogActionAsync(GetAdminUsername(), "DELETE_BANNER", $"Banner:{id}", beforeJson, null);

            return Ok(new { success = true, message = "Banner deleted successfully." });
        }

        #endregion

        #region Audit Logs View

        [HttpGet("audit-logs")]
        public async Task<IActionResult> GetAuditLogs([FromQuery] int page = 1, [FromQuery] int pageSize = 30)
        {
            var query = _context.AuditLogs.AsQueryable();
            var totalLogs = await query.CountAsync();
            var logs = await query
                .OrderByDescending(l => l.Timestamp)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new
            {
                success = true,
                total_count = totalLogs,
                page = page,
                page_size = pageSize,
                logs = logs
            });
        }

        #endregion

        #region Course Management CRUD

        [HttpGet("courses")]
        public async Task<IActionResult> GetCourses([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 15)
        {
            var query = _context.Courses.AsQueryable();

            if (!string.IsNullOrEmpty(search))
            {
                var cleanSearch = search.Trim().ToLower();
                query = query.Where(c => c.Title.ToLower().Contains(cleanSearch) || 
                                         (c.Category != null && c.Category.ToLower().Contains(cleanSearch)));
            }

            var totalCourses = await query.CountAsync();
            var courses = await query
                .OrderByDescending(c => c.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new
            {
                success = true,
                total_count = totalCourses,
                page = page,
                page_size = pageSize,
                courses = courses
            });
        }

        [HttpGet("courses/{id}")]
        public async Task<IActionResult> GetCourseById(Guid id)
        {
            var course = await _context.Courses.FindAsync(id);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            return Ok(new { success = true, course });
        }

        [HttpPost("courses/upload")]
        [RequestSizeLimit(100_000_000)] // 100MB max limit
        public async Task<IActionResult> UploadCoursePackage([FromForm] IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { success = false, message = "No file uploaded." });
            }

            if (!file.FileName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { success = false, message = "File must be a ZIP archive." });
            }

            var tempZipPath = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.zip");
            var tempExtractDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());

            try
            {
                // Save zip to temp path
                using (var stream = new FileStream(tempZipPath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                // Extract ZIP
                System.IO.Compression.ZipFile.ExtractToDirectory(tempZipPath, tempExtractDir);

                var manifestPath = Path.Combine(tempExtractDir, "manifest.json");
                var dbPath = Path.Combine(tempExtractDir, "course.db");

                if (!System.IO.File.Exists(manifestPath))
                {
                    return BadRequest(new { success = false, message = "manifest.json is missing in the package." });
                }

                if (!System.IO.File.Exists(dbPath))
                {
                    return BadRequest(new { success = false, message = "course.db is missing in the package." });
                }

                // 1. Read manifest.json
                var manifestContent = await System.IO.File.ReadAllTextAsync(manifestPath);
                using var doc = JsonDocument.Parse(manifestContent);
                var root = doc.RootElement;

                var courseIdStr = root.GetProperty("course_id").GetString();
                if (!Guid.TryParse(courseIdStr, out var courseId))
                {
                    return BadRequest(new { success = false, message = "Invalid course_id in manifest.json." });
                }

                var title = root.GetProperty("title").GetString() ?? "Untitled Course";
                
                string? description = null;
                if (root.TryGetProperty("description", out var descProp)) description = descProp.GetString();
                
                string? category = null;
                if (root.TryGetProperty("category", out var catProp)) category = catProp.GetString();
                
                string? difficulty = null;
                if (root.TryGetProperty("difficulty", out var diffProp)) difficulty = diffProp.GetString();

                decimal price = 0;
                if (root.TryGetProperty("price", out var priceProp)) price = priceProp.GetDecimal();

                int version = 1;
                if (root.TryGetProperty("version", out var versionProp)) version = versionProp.GetInt32();

                int cardCount = 0;
                if (root.TryGetProperty("card_count", out var countProp)) cardCount = countProp.GetInt32();

                string? checksum = null;
                if (root.TryGetProperty("db_checksum_sha256", out var checkProp)) checksum = checkProp.GetString();

                // 2. Read cards from SQLite database using Microsoft.Data.Sqlite
                var cardsList = new System.Collections.Generic.List<Card>();
                using (var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection($"Data Source={dbPath}"))
                {
                    await sqliteConn.OpenAsync();
                    using (var sqliteCmd = new Microsoft.Data.Sqlite.SqliteCommand("SELECT card_number, question_text, answer_text, image_name, audio_name FROM cards", sqliteConn))
                    {
                        using (var reader = await sqliteCmd.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                var cardNum = reader.GetInt32(0);
                                var qText = reader.GetString(1);
                                var aText = reader.GetString(2);
                                
                                string? imgName = reader.IsDBNull(3) ? null : reader.GetString(3);
                                string? audName = reader.IsDBNull(4) ? null : reader.GetString(4);

                                cardsList.Add(new Card
                                {
                                    Id = Guid.NewGuid(),
                                    CourseId = courseId,
                                    CardNumber = cardNum,
                                    QuestionText = qText,
                                    AnswerText = aText,
                                    ImageUrl = imgName,
                                    AudioUrl = audName
                                });
                            }
                        }
                    }
                }

                if (cardsList.Count != cardCount)
                {
                    cardCount = cardsList.Count;
                }

                // 3. Save package file to wwwroot/courses/{course_id}.zip
                var wwwrootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
                var coursesDir = Path.Combine(wwwrootPath, "courses");
                if (!Directory.Exists(coursesDir))
                {
                    Directory.CreateDirectory(coursesDir);
                }

                var targetZipPath = Path.Combine(coursesDir, $"{courseId}.zip");
                if (System.IO.File.Exists(targetZipPath))
                {
                    System.IO.File.Delete(targetZipPath);
                }
                System.IO.File.Copy(tempZipPath, targetZipPath);

                var relativeDownloadUrl = $"/courses/{courseId}.zip";

                // 4. Update or Insert in PostgreSQL
                using (var transaction = await _context.Database.BeginTransactionAsync())
                {
                    try
                    {
                        var existingCourse = await _context.Courses.FindAsync(courseId);
                        string? beforeJson = existingCourse != null ? JsonSerializer.Serialize(existingCourse) : null;

                        if (existingCourse != null)
                        {
                            existingCourse.Title = title;
                            existingCourse.Description = description;
                            existingCourse.Category = category;
                            existingCourse.Difficulty = difficulty;
                            existingCourse.Price = price;
                            existingCourse.Version = version;
                            existingCourse.ChecksumSha256 = checksum;
                            existingCourse.DownloadUrl = relativeDownloadUrl;
                            existingCourse.CardCount = cardCount;

                            _context.Entry(existingCourse).State = EntityState.Modified;

                            // Remove existing cards
                            var oldCards = _context.Cards.Where(c => c.CourseId == courseId);
                            _context.Cards.RemoveRange(oldCards);
                            
                            // Insert new cards
                            await _context.Cards.AddRangeAsync(cardsList);
                            await _context.SaveChangesAsync();

                            var afterJson = JsonSerializer.Serialize(existingCourse);
                            await _auditLogService.LogActionAsync(
                                GetAdminUsername(),
                                "UPDATE_COURSE",
                                $"Course:{courseId}",
                                beforeJson,
                                afterJson
                            );
                        }
                        else
                        {
                            var newCourse = new Course
                            {
                                Id = courseId,
                                Title = title,
                                Description = description,
                                Category = category,
                                Difficulty = difficulty,
                                Price = price,
                                IsPublished = false,
                                Version = version,
                                ChecksumSha256 = checksum,
                                DownloadUrl = relativeDownloadUrl,
                                CardCount = cardCount,
                                CreatedAt = DateTime.UtcNow
                            };

                            await _context.Courses.AddAsync(newCourse);
                            await _context.Cards.AddRangeAsync(cardsList);
                            await _context.SaveChangesAsync();

                            var afterJson = JsonSerializer.Serialize(newCourse);
                            await _auditLogService.LogActionAsync(
                                GetAdminUsername(),
                                "CREATE_COURSE",
                                $"Course:{courseId}",
                                null,
                                afterJson
                            );
                        }

                        await transaction.CommitAsync();
                    }
                    catch (Exception)
                    {
                        await transaction.RollbackAsync();
                        throw;
                    }
                }

                return Ok(new { success = true, message = "Course package uploaded and parsed successfully.", course_id = courseId });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Failed to process package. Error: {ex.Message}" });
            }
            finally
            {
                try
                {
                    if (System.IO.File.Exists(tempZipPath)) System.IO.File.Delete(tempZipPath);
                    if (Directory.Exists(tempExtractDir)) Directory.Delete(tempExtractDir, true);
                }
                catch { /* ignore */ }
            }
        }

        [HttpPut("courses/{id}")]
        public async Task<IActionResult> UpdateCourse(Guid id, [FromBody] AdminCourseUpdateInput input)
        {
            var course = await _context.Courses.FindAsync(id);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            var beforeJson = JsonSerializer.Serialize(course);

            course.Title = input.Title ?? course.Title;
            course.Description = input.Description ?? course.Description;
            course.Category = input.Category ?? course.Category;
            course.Difficulty = input.Difficulty ?? course.Difficulty;
            if (input.Price.HasValue) course.Price = input.Price.Value;
            if (input.IsPublished.HasValue) course.IsPublished = input.IsPublished.Value;

            _context.Entry(course).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(course);
            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "UPDATE_COURSE_METADATA",
                $"Course:{id}",
                beforeJson,
                afterJson
            );

            return Ok(new { success = true, message = "Course metadata updated successfully.", course });
        }

        [HttpDelete("courses/{id}")]
        public async Task<IActionResult> DeleteCourse(Guid id)
        {
            var course = await _context.Courses.FindAsync(id);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            var beforeJson = JsonSerializer.Serialize(course);

            // Delete course package file from disk
            try
            {
                var targetZipPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "courses", $"{id}.zip");
                if (System.IO.File.Exists(targetZipPath))
                {
                    System.IO.File.Delete(targetZipPath);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: Failed to delete physical course ZIP file. Error: {ex.Message}");
            }

            _context.Courses.Remove(course);
            await _context.SaveChangesAsync();

            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "DELETE_COURSE",
                $"Course:{id}",
                beforeJson,
                null
            );

            return Ok(new { success = true, message = "Course and all related cards deleted successfully." });
        }

        #endregion

        #region System Config CRUD

        [HttpGet("config")]
        public async Task<IActionResult> GetSystemConfig()
        {
            var configs = await _context.SystemConfigs.ToListAsync();
            return Ok(new { success = true, configs });
        }

        [HttpPut("config")]
        public async Task<IActionResult> UpdateSystemConfig([FromBody] SystemConfigUpdateInput input)
        {
            if (input == null || input.Configs == null)
            {
                return BadRequest(new { success = false, message = "Invalid settings data." });
            }

            var beforeConfigs = await _context.SystemConfigs.AsNoTracking().ToListAsync();
            var beforeJson = JsonSerializer.Serialize(beforeConfigs);

            foreach (var item in input.Configs)
            {
                var existing = await _context.SystemConfigs.FindAsync(item.Key);
                if (existing != null)
                {
                    existing.Value = item.Value;
                    existing.UpdatedAt = DateTime.UtcNow;
                    _context.Entry(existing).State = EntityState.Modified;
                }
                else
                {
                    var newConfig = new SystemConfig
                    {
                        Key = item.Key,
                        Value = item.Value,
                        UpdatedAt = DateTime.UtcNow
                    };
                    await _context.SystemConfigs.AddAsync(newConfig);
                }
            }

            await _context.SaveChangesAsync();

            var afterConfigs = await _context.SystemConfigs.AsNoTracking().ToListAsync();
            var afterJson = JsonSerializer.Serialize(afterConfigs);

            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "UPDATE_SYSTEM_CONFIG",
                "SystemSettings",
                beforeJson,
                afterJson
            );

            return Ok(new { success = true, message = "System configuration updated successfully." });
        }

        #endregion
    }

    #region Input DTOs

    public class AdminCourseUpdateInput
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Category { get; set; }
        public string? Difficulty { get; set; }
        public decimal? Price { get; set; }
        public bool? IsPublished { get; set; }
    }

    public class AdminUserUpdateInput
    {
        public string? Username { get; set; }
        public string? Interests { get; set; }
        public string? EducationalField { get; set; }
        public string? EducationalLevel { get; set; }
        public bool? IsAdmin { get; set; }
    }

    public class ToggleCourseAccessInput
    {
        public bool GrantAccess { get; set; }
        public string? Reason { get; set; }
    }

    public class UpdateReportStatusInput
    {
        public string? Status { get; set; } // 'PENDING', 'REVIEWED', 'RESOLVED'
    }

    public class AnnouncementInput
    {
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
    }

    public class BannerInput
    {
        public string ImageUrl { get; set; } = string.Empty;
        public string? LinkUrl { get; set; }
        public int DisplayOrder { get; set; }
        public bool? IsActive { get; set; }
    }

    public class SystemConfigUpdateInput
    {
        public System.Collections.Generic.List<SystemConfigItemInput>? Configs { get; set; }
    }

    public class SystemConfigItemInput
    {
        public string Key { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
    }

    #endregion
}
