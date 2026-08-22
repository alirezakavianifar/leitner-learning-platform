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
        private readonly ILogger<AdminController> _logger;

        public AdminController(LeitnerDbContext context, IEventBus eventBus, IAuditLogService auditLogService, ILogger<AdminController> logger)
        {
            _context = context;
            _eventBus = eventBus;
            _auditLogService = auditLogService;
            _logger = logger;
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
        public async Task<IActionResult> GetCourses([FromQuery] string? search, [FromQuery] bool includeArchived = false, [FromQuery] int page = 1, [FromQuery] int pageSize = 15)
        {
            var query = _context.Courses.AsQueryable();

            if (!includeArchived)
            {
                query = query.Where(c => !c.IsArchived);
            }

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

            try
            {
                using (var stream = new FileStream(tempZipPath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                return await ProcessZipPackageInternal(tempZipPath, file.FileName);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Failed to save uploaded file: {ex.Message}" });
            }
        }

        [HttpPost("courses/upload-chunk")]
        [RequestSizeLimit(20_000_000)] // 20MB chunk max limit
        public async Task<IActionResult> UploadCourseChunk(
            IFormFile file,
            [FromForm(Name = "uploadId")] string uploadId,
            [FromForm(Name = "chunkIndex")] int chunkIndex,
            [FromForm(Name = "totalChunks")] int totalChunks,
            [FromForm(Name = "fileName")] string fileName)
        {
            // Bind fields individually (not via a complex DTO). Complex [FromForm] DTOs that
            // also contain IFormFile have been observed to leave int fields at their defaults
            // (ChunkIndex=0), which made every chunk overwrite chunk_00000.tmp and left the
            // admin UI stuck at ~20% for multi-chunk packages such as 1100.zip.
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { success = false, message = "Chunk file is empty." });
            }

            if (string.IsNullOrEmpty(uploadId))
            {
                return BadRequest(new { success = false, message = "UploadId is required." });
            }

            if (totalChunks <= 0 || chunkIndex < 0 || chunkIndex >= totalChunks)
            {
                return BadRequest(new
                {
                    success = false,
                    message = $"Invalid chunk metadata (chunkIndex={chunkIndex}, totalChunks={totalChunks})."
                });
            }

            var chunkDir = Path.Combine(Path.GetTempPath(), "chunks", uploadId);
            if (!Directory.Exists(chunkDir))
            {
                Directory.CreateDirectory(chunkDir);
            }

            var chunkFilePath = Path.Combine(chunkDir, $"chunk_{chunkIndex:D5}.tmp");
            using (var stream = new FileStream(chunkFilePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            _logger.LogInformation(
                "Received course upload chunk {ChunkIndex}/{TotalChunks} for upload {UploadId} ({Bytes} bytes)",
                chunkIndex + 1, totalChunks, uploadId, file.Length);

            var uploadedChunks = Directory.GetFiles(chunkDir, "chunk_*.tmp");
            var distinctIndices = uploadedChunks
                .Select(p => Path.GetFileNameWithoutExtension(p))
                .Where(n => n.StartsWith("chunk_"))
                .Select(n => int.TryParse(n.Substring(6), out int idx) ? idx : -1)
                .Where(idx => idx >= 0 && idx < totalChunks)
                .ToHashSet();

            if (distinctIndices.Count < totalChunks)
            {
                return Ok(new { success = true, message = $"Chunk {chunkIndex + 1}/{totalChunks} received.", completed = false });
            }

            // Reassemble chunks into single ZIP file (ordered by padded index in the filename).
            Array.Sort(uploadedChunks, StringComparer.Ordinal);
            var tempZipPath = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.zip");
            using (var destinationStream = new FileStream(tempZipPath, FileMode.Create))
            {
                foreach (var chunkPath in uploadedChunks)
                {
                    using (var sourceStream = new FileStream(chunkPath, FileMode.Open, FileAccess.Read))
                    {
                        await sourceStream.CopyToAsync(destinationStream);
                    }
                }
            }

            try { Directory.Delete(chunkDir, true); } catch { }

            return await ProcessZipPackageInternal(tempZipPath, fileName);
        }

        private async Task<IActionResult> ProcessZipPackageInternal(string tempZipPath, string originalFileName)
        {
            var tempExtractDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());

            try
            {
                // Extract ZIP
                System.IO.Compression.ZipFile.ExtractToDirectory(tempZipPath, tempExtractDir);

                // 1. Find manifest.json and SQLite database file (*.db) recursively
                var manifestFiles = Directory.GetFiles(tempExtractDir, "manifest.json", SearchOption.AllDirectories);
                var manifestPath = manifestFiles.Length > 0 ? manifestFiles[0] : null;

                var dbFiles = Directory.GetFiles(tempExtractDir, "*.db", SearchOption.AllDirectories);
                if (dbFiles.Length == 0)
                {
                    return BadRequest(new { success = false, message = "No SQLite database (.db) file found in the uploaded package." });
                }
                var dbPath = dbFiles[0];

                Guid courseId;
                string title;
                string? description = null;
                string? category = null;
                string? difficulty = null;
                decimal price = 0;
                int version = 1;
                int cardCount = 0;
                string? checksum = null;

                bool isPublished = true;
                bool isCriticalUpdate = false;

                if (manifestPath != null && System.IO.File.Exists(manifestPath))
                {
                    var manifestContent = await System.IO.File.ReadAllTextAsync(manifestPath);
                    using var doc = JsonDocument.Parse(manifestContent);
                    var root = doc.RootElement;

                    var courseIdStr = root.GetProperty("course_id").GetString();
                    if (!Guid.TryParse(courseIdStr, out courseId))
                    {
                        return BadRequest(new { success = false, message = "Invalid course_id in manifest.json." });
                    }

                    title = root.GetProperty("title").GetString() ?? "Untitled Course";
                    if (root.TryGetProperty("description", out var descProp)) description = descProp.GetString();
                    if (root.TryGetProperty("category", out var catProp)) category = catProp.GetString();
                    if (root.TryGetProperty("difficulty", out var diffProp)) difficulty = diffProp.GetString();
                    if (root.TryGetProperty("price", out var priceProp)) price = priceProp.GetDecimal();
                    if (root.TryGetProperty("version", out var versionProp)) version = versionProp.GetInt32();
                    if (root.TryGetProperty("card_count", out var countProp)) cardCount = countProp.GetInt32();
                    if (root.TryGetProperty("db_checksum_sha256", out var checkProp)) checksum = checkProp.GetString();
                    if (root.TryGetProperty("is_published", out var pubProp)) isPublished = pubProp.GetBoolean();
                    if (root.TryGetProperty("is_critical_update", out var criticalProp)) isCriticalUpdate = criticalProp.GetBoolean();
                }
                else
                {
                    // Fallback metadata generation for packages without manifest.json (e.g. 1100.zip)
                    var fileNameNoExt = Path.GetFileNameWithoutExtension(originalFileName);
                    if (fileNameNoExt.Equals("1100", StringComparison.OrdinalIgnoreCase))
                    {
                        courseId = Guid.Parse("11000000-0000-0000-0000-000000001100");
                        title = "1100 Words You Need to Know";
                        description = "Master 1,100 essential English vocabulary words with sentences, Persian translations, and native audio pronunciations.";
                        category = "Vocabulary";
                        difficulty = "Intermediate";
                    }
                    else if (fileNameNoExt.Equals("504", StringComparison.OrdinalIgnoreCase))
                    {
                        courseId = Guid.Parse("50400000-0000-0000-0000-000000000504");
                        title = "504 Absolutely Essential Words";
                        description = "Master 504 essential English vocabulary words with sentences, Persian translations, and native audio pronunciations.";
                        category = "Vocabulary";
                        difficulty = "Intermediate";
                    }
                    else
                    {
                        courseId = Guid.NewGuid();
                        title = fileNameNoExt;
                        category = "General";
                        difficulty = "Intermediate";
                    }
                }

                // Note: the manifest's "db_checksum_sha256" (if present) describes the checksum of the
                // authored course.db, not of the distributable package. The checksum actually verified by
                // the mobile client is always computed below, from the exact ZIP bytes it will download.

                // 2. Read cards from SQLite database dynamically supporting various column naming conventions
                var cardsList = new System.Collections.Generic.List<Card>();
                using (var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection($"Data Source={dbPath}"))
                {
                    await sqliteConn.OpenAsync();

                    // Retrieve column schema
                    var columns = new System.Collections.Generic.List<string>();
                    using (var schemaCmd = new Microsoft.Data.Sqlite.SqliteCommand("PRAGMA table_info(cards)", sqliteConn))
                    using (var reader = await schemaCmd.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            columns.Add(reader.GetString(1).ToLowerInvariant());
                        }
                    }

                    int idxCardNum = columns.IndexOf("card_number");
                    if (idxCardNum == -1) idxCardNum = columns.IndexOf("number");
                    if (idxCardNum == -1) idxCardNum = columns.IndexOf("id");

                    int idxQuestion = columns.IndexOf("question_text");
                    if (idxQuestion == -1) idxQuestion = columns.IndexOf("questions");
                    if (idxQuestion == -1) idxQuestion = columns.IndexOf("question");
                    if (idxQuestion == -1) idxQuestion = columns.IndexOf("front");

                    int idxAnswer = columns.IndexOf("answer_text");
                    if (idxAnswer == -1) idxAnswer = columns.IndexOf("answer");
                    if (idxAnswer == -1) idxAnswer = columns.IndexOf("answers");
                    if (idxAnswer == -1) idxAnswer = columns.IndexOf("back");

                    int idxImage = columns.IndexOf("image_name");
                    if (idxImage == -1) idxImage = columns.IndexOf("front image");
                    if (idxImage == -1) idxImage = columns.IndexOf("image");
                    if (idxImage == -1) idxImage = columns.IndexOf("image_url");

                    int idxAudio = columns.IndexOf("audio_name");
                    if (idxAudio == -1) idxAudio = columns.IndexOf("front voice");
                    if (idxAudio == -1) idxAudio = columns.IndexOf("audio");
                    if (idxAudio == -1) idxAudio = columns.IndexOf("audio_url");

                    using (var sqliteCmd = new Microsoft.Data.Sqlite.SqliteCommand("SELECT * FROM cards", sqliteConn))
                    using (var reader = await sqliteCmd.ExecuteReaderAsync())
                    {
                        int rowCounter = 1;
                        while (await reader.ReadAsync())
                        {
                            int cardNum = idxCardNum != -1 && !reader.IsDBNull(idxCardNum) ? Convert.ToInt32(reader.GetValue(idxCardNum)) : rowCounter;
                            string qText = idxQuestion != -1 && !reader.IsDBNull(idxQuestion) ? reader.GetString(idxQuestion) : "Question";
                            string aText = idxAnswer != -1 && !reader.IsDBNull(idxAnswer) ? reader.GetString(idxAnswer) : "Answer";
                            string? imgName = idxImage != -1 && !reader.IsDBNull(idxImage) ? reader.GetString(idxImage) : null;
                            string? audName = idxAudio != -1 && !reader.IsDBNull(idxAudio) ? reader.GetString(idxAudio) : null;

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
                            rowCounter++;
                        }
                    }
                }

                if (cardsList.Count != cardCount)
                {
                    cardCount = cardsList.Count;
                }

                // 3. Build a mobile-compatible package and save it to wwwroot/courses/{course_id}.zip.
                // We never store the raw uploaded ZIP verbatim: legacy/author packages (e.g. 504.zip) nest
                // the .db file inside a subfolder, use non-standard column names, and keep media in
                // arbitrarily named folders (e.g. "pronunciation/"). The mobile client strictly requires a
                // root-level "course.db" (matching docs/course/course_db_specification.md) plus flattened
                // "images/"/"audio/" folders, or it fails to process the download entirely.
                var wwwrootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
                var coursesDir = Path.Combine(wwwrootPath, "courses");
                var relativeDownloadUrl = $"/courses/{courseId}.zip";
                var builtZipPath = await BuildCompliantCoursePackageZipAsync(
                    tempExtractDir, courseId, title, description, category, difficulty, price, version, cardsList);

                try
                {
                    if (!Directory.Exists(coursesDir))
                    {
                        Directory.CreateDirectory(coursesDir);
                    }

                    var targetZipPath = Path.Combine(coursesDir, $"{courseId}.zip");
                    if (System.IO.File.Exists(targetZipPath))
                    {
                        System.IO.File.Delete(targetZipPath);
                    }
                    System.IO.File.Copy(builtZipPath, targetZipPath);

                    // The checksum returned to clients must match the exact bytes they will download & hash.
                    using var sha256 = System.Security.Cryptography.SHA256.Create();
                    using var checksumStream = System.IO.File.OpenRead(targetZipPath);
                    var hashBytes = await sha256.ComputeHashAsync(checksumStream);
                    checksum = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Could not save built course package to wwwroot/courses: {Message}", ex.Message);
                    try { if (System.IO.File.Exists(builtZipPath)) System.IO.File.Delete(builtZipPath); } catch { }
                    return StatusCode(500, new
                    {
                        success = false,
                        message = $"Course metadata was parsed, but the mobile package could not be saved to disk: {ex.Message}"
                    });
                }
                finally
                {
                    try { if (System.IO.File.Exists(builtZipPath)) System.IO.File.Delete(builtZipPath); } catch { }
                }

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
                            existingCourse.IsPublished = isPublished;
                            existingCourse.IsCriticalUpdate = isCriticalUpdate;
                            existingCourse.UpdatedAt = DateTime.UtcNow;
                            // Re-uploading a package is an explicit admin action to bring the
                            // course back into circulation, so reverse any prior archive state.
                            existingCourse.IsArchived = false;
                            existingCourse.ArchivedAt = null;

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
                                IsPublished = isPublished,
                                Version = version,
                                ChecksumSha256 = checksum,
                                DownloadUrl = relativeDownloadUrl,
                                CardCount = cardCount,
                                IsCriticalUpdate = isCriticalUpdate,
                                CreatedAt = DateTime.UtcNow,
                                UpdatedAt = DateTime.UtcNow
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

                return Ok(new { success = true, message = "Course package uploaded and parsed successfully.", course_id = courseId, completed = true });
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
                catch { }
            }
        }

        /// <summary>
        /// Builds a mobile-client-compatible course package from whatever layout the author uploaded.
        /// Produces a ZIP containing a root-level "course.db" (schema per
        /// docs/course/course_db_specification.md) plus flattened "images/" and "audio/" folders,
        /// regardless of how the source package nested its .db file or media assets.
        /// </summary>
        private async Task<string> BuildCompliantCoursePackageZipAsync(
            string sourceExtractDir,
            Guid courseId,
            string title,
            string? description,
            string? category,
            string? difficulty,
            decimal price,
            int version,
            System.Collections.Generic.List<Card> cardsList)
        {
            var buildDir = Path.Combine(Path.GetTempPath(), $"pkg_{Guid.NewGuid()}");
            var imagesDir = Path.Combine(buildDir, "images");
            var audioDir = Path.Combine(buildDir, "audio");
            Directory.CreateDirectory(imagesDir);
            Directory.CreateDirectory(audioDir);

            // Index every non-db, non-manifest file from the source package by filename so legacy
            // packages with nested/renamed media folders (e.g. "pronunciation/word.mp3") still resolve.
            var mediaIndex = Directory.GetFiles(sourceExtractDir, "*.*", SearchOption.AllDirectories)
                .Where(f => !f.EndsWith(".db", StringComparison.OrdinalIgnoreCase)
                         && !Path.GetFileName(f).Equals("manifest.json", StringComparison.OrdinalIgnoreCase))
                .GroupBy(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

            foreach (var card in cardsList)
            {
                if (!string.IsNullOrEmpty(card.ImageUrl) && mediaIndex.TryGetValue(card.ImageUrl, out var imgSrc))
                {
                    var dest = Path.Combine(imagesDir, Path.GetFileName(card.ImageUrl));
                    if (!System.IO.File.Exists(dest)) System.IO.File.Copy(imgSrc, dest);
                }
                if (!string.IsNullOrEmpty(card.AudioUrl) && mediaIndex.TryGetValue(card.AudioUrl, out var audSrc))
                {
                    var dest = Path.Combine(audioDir, Path.GetFileName(card.AudioUrl));
                    if (!System.IO.File.Exists(dest)) System.IO.File.Copy(audSrc, dest);
                }
            }

            var dbPath = Path.Combine(buildDir, "course.db");
            if (System.IO.File.Exists(dbPath)) System.IO.File.Delete(dbPath);

            using (var conn = new Microsoft.Data.Sqlite.SqliteConnection($"Data Source={dbPath}"))
            {
                await conn.OpenAsync();

                using (var schemaCmd = conn.CreateCommand())
                {
                    schemaCmd.CommandText = @"
                        CREATE TABLE IF NOT EXISTS course (
                            id TEXT PRIMARY KEY,
                            title TEXT NOT NULL,
                            description TEXT,
                            category TEXT,
                            difficulty TEXT,
                            price REAL NOT NULL DEFAULT 0.0,
                            version INTEGER NOT NULL DEFAULT 1,
                            created_at TEXT NOT NULL
                        );
                        CREATE TABLE IF NOT EXISTS cards (
                            id TEXT PRIMARY KEY,
                            course_id TEXT NOT NULL,
                            card_number INTEGER NOT NULL,
                            question_text TEXT NOT NULL,
                            answer_text TEXT NOT NULL,
                            image_name TEXT,
                            audio_name TEXT
                        );
                        CREATE UNIQUE INDEX IF NOT EXISTS idx_cards_course_number ON cards (course_id, card_number);
                    ";
                    await schemaCmd.ExecuteNonQueryAsync();
                }

                using (var tx = conn.BeginTransaction())
                {
                    using (var courseCmd = conn.CreateCommand())
                    {
                        courseCmd.Transaction = tx;
                        courseCmd.CommandText = "INSERT INTO course (id, title, description, category, difficulty, price, version, created_at) " +
                                                 "VALUES ($id,$title,$description,$category,$difficulty,$price,$version,$createdAt)";
                        courseCmd.Parameters.AddWithValue("$id", courseId.ToString());
                        courseCmd.Parameters.AddWithValue("$title", title);
                        courseCmd.Parameters.AddWithValue("$description", (object?)description ?? DBNull.Value);
                        courseCmd.Parameters.AddWithValue("$category", (object?)category ?? DBNull.Value);
                        courseCmd.Parameters.AddWithValue("$difficulty", (object?)difficulty ?? DBNull.Value);
                        courseCmd.Parameters.AddWithValue("$price", price);
                        courseCmd.Parameters.AddWithValue("$version", version);
                        courseCmd.Parameters.AddWithValue("$createdAt", DateTime.UtcNow.ToString("o"));
                        await courseCmd.ExecuteNonQueryAsync();
                    }

                    foreach (var card in cardsList)
                    {
                        using var cardCmd = conn.CreateCommand();
                        cardCmd.Transaction = tx;
                        cardCmd.CommandText = "INSERT INTO cards (id, course_id, card_number, question_text, answer_text, image_name, audio_name) " +
                                               "VALUES ($id,$courseId,$cardNumber,$question,$answer,$image,$audio)";
                        cardCmd.Parameters.AddWithValue("$id", card.Id.ToString());
                        cardCmd.Parameters.AddWithValue("$courseId", courseId.ToString());
                        cardCmd.Parameters.AddWithValue("$cardNumber", card.CardNumber);
                        cardCmd.Parameters.AddWithValue("$question", card.QuestionText);
                        cardCmd.Parameters.AddWithValue("$answer", card.AnswerText);
                        cardCmd.Parameters.AddWithValue("$image", (object?)(card.ImageUrl != null ? Path.GetFileName(card.ImageUrl) : null) ?? DBNull.Value);
                        cardCmd.Parameters.AddWithValue("$audio", (object?)(card.AudioUrl != null ? Path.GetFileName(card.AudioUrl) : null) ?? DBNull.Value);
                        await cardCmd.ExecuteNonQueryAsync();
                    }

                    await tx.CommitAsync();
                }
            }
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();

            if (Directory.GetFiles(imagesDir).Length == 0) Directory.Delete(imagesDir, true);
            if (Directory.GetFiles(audioDir).Length == 0) Directory.Delete(audioDir, true);

            var outputZipPath = Path.Combine(Path.GetTempPath(), $"built_{courseId}_{Guid.NewGuid()}.zip");
            if (System.IO.File.Exists(outputZipPath)) System.IO.File.Delete(outputZipPath);
            System.IO.Compression.ZipFile.CreateFromDirectory(buildDir, outputZipPath, System.IO.Compression.CompressionLevel.Optimal, false);

            try { Directory.Delete(buildDir, true); } catch { }

            return outputZipPath;
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
            if (input.IsCriticalUpdate.HasValue) course.IsCriticalUpdate = input.IsCriticalUpdate.Value;
            course.UpdatedAt = DateTime.UtcNow;

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

        /// <summary>
        /// Archives (soft-deletes) a course: hides it from the public catalog and the
        /// default admin course list, but keeps its row, cards, package file, and all
        /// existing purchases intact so users who already bought/downloaded it keep access.
        /// Use POST courses/{id}/unarchive to reverse, or DELETE courses/{id}/purge for a
        /// permanent, destructive removal.
        /// </summary>
        [HttpDelete("courses/{id}")]
        public async Task<IActionResult> DeleteCourse(Guid id)
        {
            var course = await _context.Courses.FindAsync(id);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            if (course.IsArchived)
            {
                return Ok(new { success = true, message = "Course is already archived." });
            }

            var beforeJson = JsonSerializer.Serialize(course);

            course.IsArchived = true;
            course.ArchivedAt = DateTime.UtcNow;
            course.IsPublished = false;
            course.UpdatedAt = DateTime.UtcNow;

            _context.Entry(course).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(course);
            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "ARCHIVE_COURSE",
                $"Course:{id}",
                beforeJson,
                afterJson
            );

            return Ok(new { success = true, message = "Course archived successfully. Existing buyers keep access; it is hidden from the store." });
        }

        /// <summary>
        /// Reverses an archive: re-hides no fields, but sets IsArchived = false. Admin must
        /// still explicitly re-publish via PUT courses/{id} (IsPublished) if desired.
        /// </summary>
        [HttpPost("courses/{id}/unarchive")]
        public async Task<IActionResult> UnarchiveCourse(Guid id)
        {
            var course = await _context.Courses.FindAsync(id);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            var beforeJson = JsonSerializer.Serialize(course);

            course.IsArchived = false;
            course.ArchivedAt = null;
            course.UpdatedAt = DateTime.UtcNow;

            _context.Entry(course).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(course);
            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "UNARCHIVE_COURSE",
                $"Course:{id}",
                beforeJson,
                afterJson
            );

            return Ok(new { success = true, message = "Course unarchived successfully.", course });
        }

        /// <summary>
        /// Permanently and irreversibly deletes a course: removes the row (cascading to
        /// cards, purchases, progress, and reports), and deletes the package file from disk.
        /// Intended only for legal/compliance removals or cleaning up test data - NOT for
        /// routine "take this course down" workflows, which should use DELETE courses/{id}
        /// (archive) instead so paying customers don't lose access.
        /// </summary>
        [HttpDelete("courses/{id}/purge")]
        public async Task<IActionResult> PurgeCourse(Guid id)
        {
            var course = await _context.Courses.FindAsync(id);
            if (course == null)
            {
                return NotFound(new { success = false, message = "Course not found." });
            }

            var beforeJson = JsonSerializer.Serialize(course);

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
                "PURGE_COURSE",
                $"Course:{id}",
                beforeJson,
                null
            );

            return Ok(new { success = true, message = "Course and all related cards, purchases, and progress permanently deleted." });
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

        #region Package Management

        [HttpGet("packages")]
        public async Task<IActionResult> GetAdminPackages([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 15)
        {
            var query = _context.CoursePackages
                .Include(p => p.Items)
                    .ThenInclude(i => i.Course)
                .AsQueryable();

            if (!string.IsNullOrEmpty(search))
            {
                var cleanSearch = search.Trim().ToLower();
                query = query.Where(p => p.Title.ToLower().Contains(cleanSearch) || (p.Category != null && p.Category.ToLower().Contains(cleanSearch)));
            }

            var totalCount = await query.CountAsync();
            var packages = await query
                .OrderBy(p => p.DisplayOrder)
                .ThenByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var result = packages.Select(pkg => new
            {
                id = pkg.Id,
                title = pkg.Title,
                description = pkg.Description,
                category = pkg.Category,
                price = pkg.Price,
                original_price = pkg.OriginalPrice,
                is_published = pkg.IsPublished,
                is_archived = pkg.IsArchived,
                display_order = pkg.DisplayOrder,
                created_at = pkg.CreatedAt,
                updated_at = pkg.UpdatedAt,
                courses = pkg.Items.OrderBy(i => i.DisplayOrder).Select(i => new
                {
                    id = i.CourseId,
                    title = i.Course?.Title ?? "Unknown Course",
                    price = i.Course?.Price ?? 0m,
                    card_count = i.Course?.CardCount ?? 0,
                    is_published = i.Course?.IsPublished ?? false
                }).ToList()
            });

            return Ok(new
            {
                success = true,
                total_count = totalCount,
                page = page,
                page_size = pageSize,
                packages = result
            });
        }

        [HttpPost("packages")]
        public async Task<IActionResult> CreatePackage([FromBody] CreatePackageInput input)
        {
            if (string.IsNullOrWhiteSpace(input.Title))
            {
                return BadRequest(new { success = false, message = "Package title is required." });
            }

            var package = new CoursePackage
            {
                Id = Guid.NewGuid(),
                Title = input.Title.Trim(),
                Description = input.Description,
                Category = input.Category,
                Price = input.Price,
                OriginalPrice = input.OriginalPrice,
                IsPublished = input.IsPublished,
                DisplayOrder = input.DisplayOrder,
                CreatedAt = DateTime.UtcNow
            };

            if (input.CourseIds != null && input.CourseIds.Count > 0)
            {
                int order = 0;
                foreach (var courseId in input.CourseIds)
                {
                    package.Items.Add(new CoursePackageItem
                    {
                        PackageId = package.Id,
                        CourseId = courseId,
                        DisplayOrder = order++
                    });
                }
            }

            await _context.CoursePackages.AddAsync(package);
            await _context.SaveChangesAsync();

            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "CREATE_PACKAGE",
                $"Package:{package.Id}",
                null,
                JsonSerializer.Serialize(package)
            );

            return Ok(new { success = true, message = "Package created successfully.", package_id = package.Id });
        }

        [HttpPut("packages/{id:guid}")]
        public async Task<IActionResult> UpdatePackage(Guid id, [FromBody] UpdatePackageInput input)
        {
            var package = await _context.CoursePackages
                .Include(p => p.Items)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (package == null)
            {
                return NotFound(new { success = false, message = "Package not found." });
            }

            var beforeJson = JsonSerializer.Serialize(package);

            if (!string.IsNullOrWhiteSpace(input.Title)) package.Title = input.Title.Trim();
            if (input.Description != null) package.Description = input.Description;
            if (input.Category != null) package.Category = input.Category;
            if (input.Price.HasValue) package.Price = input.Price.Value;
            if (input.OriginalPrice.HasValue) package.OriginalPrice = input.OriginalPrice.Value;
            if (input.IsPublished.HasValue) package.IsPublished = input.IsPublished.Value;
            if (input.IsArchived.HasValue) package.IsArchived = input.IsArchived.Value;
            if (input.DisplayOrder.HasValue) package.DisplayOrder = input.DisplayOrder.Value;
            package.UpdatedAt = DateTime.UtcNow;

            if (input.CourseIds != null)
            {
                _context.CoursePackageItems.RemoveRange(package.Items);
                int order = 0;
                foreach (var courseId in input.CourseIds)
                {
                    package.Items.Add(new CoursePackageItem
                    {
                        PackageId = package.Id,
                        CourseId = courseId,
                        DisplayOrder = order++
                    });
                }
            }

            _context.Entry(package).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var afterJson = JsonSerializer.Serialize(package);
            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "UPDATE_PACKAGE",
                $"Package:{package.Id}",
                beforeJson,
                afterJson
            );

            return Ok(new { success = true, message = "Package updated successfully." });
        }

        [HttpDelete("packages/{id:guid}")]
        public async Task<IActionResult> DeletePackage(Guid id)
        {
            var package = await _context.CoursePackages.FindAsync(id);
            if (package == null)
            {
                return NotFound(new { success = false, message = "Package not found." });
            }

            var beforeJson = JsonSerializer.Serialize(package);

            package.IsArchived = true;
            package.IsPublished = false;
            package.UpdatedAt = DateTime.UtcNow;

            _context.Entry(package).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            await _auditLogService.LogActionAsync(
                GetAdminUsername(),
                "ARCHIVE_PACKAGE",
                $"Package:{id}",
                beforeJson,
                JsonSerializer.Serialize(package)
            );

            return Ok(new { success = true, message = "Package archived successfully." });
        }

        #endregion
    }

    #region Input DTOs

    public class CreatePackageInput
    {
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? Category { get; set; }
        public decimal Price { get; set; }
        public decimal? OriginalPrice { get; set; }
        public bool IsPublished { get; set; } = true;
        public int DisplayOrder { get; set; } = 0;
        public System.Collections.Generic.List<Guid>? CourseIds { get; set; }
    }

    public class UpdatePackageInput
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Category { get; set; }
        public decimal? Price { get; set; }
        public decimal? OriginalPrice { get; set; }
        public bool? IsPublished { get; set; }
        public bool? IsArchived { get; set; }
        public int? DisplayOrder { get; set; }
        public System.Collections.Generic.List<Guid>? CourseIds { get; set; }
    }

    public class AdminCourseUpdateInput
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Category { get; set; }
        public string? Difficulty { get; set; }
        public decimal? Price { get; set; }
        public bool? IsPublished { get; set; }
        public bool? IsCriticalUpdate { get; set; }
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
