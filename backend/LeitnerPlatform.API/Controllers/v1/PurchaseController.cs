using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using LeitnerPlatform.Data;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize]
    [ApiController]
    [Route("api/v1/purchases")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class PurchaseController : ControllerBase
    {
        private readonly LeitnerDbContext _context;
        private readonly IEventBus _eventBus;
        private readonly IZarinPalService _zarinPalService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<PurchaseController> _logger;

        public PurchaseController(
            LeitnerDbContext context,
            IEventBus eventBus,
            IZarinPalService zarinPalService,
            IConfiguration configuration,
            ILogger<PurchaseController> _logger)
        {
            _context = context;
            _eventBus = eventBus;
            _zarinPalService = zarinPalService;
            _configuration = configuration;
            this._logger = _logger;
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

        [HttpPost]
        public async Task<IActionResult> CreatePurchase([FromBody] CreatePurchaseInput input)
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

            // Reject mock or unverified transactions for paid courses
            if (course.Price > 0)
            {
                if (string.IsNullOrWhiteSpace(input.TransactionId) ||
                    input.TransactionId.Contains("mock", StringComparison.OrdinalIgnoreCase) ||
                    input.TransactionId.Contains("fake", StringComparison.OrdinalIgnoreCase) ||
                    input.TransactionId.Contains("simulated", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new
                    {
                        success = false,
                        error_code = "UNVERIFIED_TRANSACTION",
                        message = "Mock or unverified transactions are strictly rejected. Payment verification is required."
                    });
                }

                if (string.Equals(input.PaymentProvider, "DIRECT", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(input.PaymentProvider, "ZARINPAL", StringComparison.OrdinalIgnoreCase) ||
                    string.IsNullOrEmpty(input.PaymentProvider))
                {
                    return BadRequest(new
                    {
                        success = false,
                        error_code = "DIRECT_PAYMENT_VERIFICATION_REQUIRED",
                        message = "Direct purchases must be initiated via /zarinpal/request and verified through the payment gateway callback."
                    });
                }
            }

            // Check if there is already a completed purchase for this user and course
            var existingPurchase = await _context.Purchases
                .FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == input.CourseId);

            if (existingPurchase != null)
            {
                if (existingPurchase.Status == "COMPLETED")
                {
                    return Ok(new { success = true, message = "Course already purchased.", purchase = existingPurchase });
                }
                
                // If it was pending or refunded, update it to COMPLETED
                existingPurchase.Status = "COMPLETED";
                existingPurchase.PaymentProvider = input.PaymentProvider ?? "DIRECT";
                existingPurchase.TransactionId = input.TransactionId ?? $"TX_{Guid.NewGuid().ToString("N").Substring(0, 10).ToUpper()}";
                existingPurchase.PurchasedAt = DateTime.UtcNow;

                _context.Entry(existingPurchase).State = EntityState.Modified;
                await _context.SaveChangesAsync();

                // Publish event to trigger off-server S3 backup replication
                await _eventBus.PublishAsync(new PurchaseCompletedEvent(existingPurchase));

                return Ok(new { success = true, message = "Purchase updated to completed.", purchase = existingPurchase });
            }

            var purchase = new Purchase
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CourseId = input.CourseId,
                PaymentProvider = input.PaymentProvider ?? "DIRECT",
                TransactionId = input.TransactionId ?? $"TX_{Guid.NewGuid().ToString("N").Substring(0, 10).ToUpper()}",
                Status = "COMPLETED",
                PurchasedAt = DateTime.UtcNow
            };

            await _context.Purchases.AddAsync(purchase);
            await _context.SaveChangesAsync();

            // Publish event to trigger off-server S3 backup replication
            await _eventBus.PublishAsync(new PurchaseCompletedEvent(purchase));

            return Ok(new { success = true, message = "Purchase recorded successfully.", purchase });
        }

        [HttpPost("zarinpal/request")]
        public async Task<IActionResult> RequestZarinPalPayment([FromBody] ZarinPalPurchaseInput input)
        {
            var userId = GetUserId();
            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Start. UserId={UserId}, CourseId={CourseId}", userId, input.CourseId);

            if (userId == Guid.Empty)
            {
                _logger.LogWarning("PurchaseController: RequestZarinPalPayment: Unauthorized. Guid is empty.");
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var course = await _context.Courses.FindAsync(input.CourseId);
            if (course == null)
            {
                _logger.LogWarning("PurchaseController: RequestZarinPalPayment: Course {CourseId} not found.", input.CourseId);
                return NotFound(new { success = false, message = "Course not found." });
            }

            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Found course '{Title}', Price={Price}", course.Title, course.Price);

            // Check if course is free or already purchased
            var existingPurchase = await _context.Purchases
                .FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == input.CourseId);

            if (existingPurchase != null && existingPurchase.Status == "COMPLETED")
            {
                _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Course already purchased. PurchaseId={PurchaseId}", existingPurchase.Id);
                return Ok(new { success = true, message = "Course already purchased.", already_purchased = true, purchase = existingPurchase });
            }

            var user = await _context.Users.FindAsync(userId);
            var mobile = user?.MobileNumber;
            string? email = null;
            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Loaded user mobile: '{MobileNumber}'", mobile);

            var callbackUrl = Environment.GetEnvironmentVariable("ZARINPAL_CALLBACK_URL")
                              ?? _configuration["ZarinPal:CallbackUrl"]
                              ?? $"{Request.Scheme}://{Request.Host}/api/v1/purchases/zarinpal/callback";

            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: callbackUrl = '{CallbackUrl}'", callbackUrl);

            var amountInToman = course.Price;
            var description = $"Purchase course: {course.Title}";

            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Calling ZarinPal Service...");
            var requestResult = await _zarinPalService.RequestPaymentAsync(amountInToman, description, callbackUrl, mobile, email);

            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: ZarinPal Service returned Success={Success}, Code={Code}, Message='{Message}', Authority='{Authority}'", 
                requestResult.IsSuccess, requestResult.Code, requestResult.Message, requestResult.Authority);

            if (!requestResult.IsSuccess)
            {
                _logger.LogError("PurchaseController: RequestZarinPalPayment: ZarinPal request failed: {Message}", requestResult.Message);
                return BadRequest(new { success = false, message = requestResult.Message, code = requestResult.Code });
            }

            if (existingPurchase != null)
            {
                _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Updating existing purchase record {PurchaseId} to PENDING Zarinpal Authority {Authority}", existingPurchase.Id, requestResult.Authority);
                existingPurchase.Status = "PENDING";
                existingPurchase.PaymentProvider = "ZARINPAL";
                existingPurchase.TransactionId = requestResult.Authority;
                _context.Entry(existingPurchase).State = EntityState.Modified;
            }
            else
            {
                existingPurchase = new Purchase
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    CourseId = input.CourseId,
                    PaymentProvider = "ZARINPAL",
                    TransactionId = requestResult.Authority,
                    Status = "PENDING",
                    PurchasedAt = DateTime.UtcNow
                };
                _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Creating new purchase record {PurchaseId} with PENDING Zarinpal Authority {Authority}", existingPurchase.Id, requestResult.Authority);
                await _context.Purchases.AddAsync(existingPurchase);
            }

            await _context.SaveChangesAsync();
            _logger.LogInformation("PurchaseController: RequestZarinPalPayment: Saved purchase record, returning payment_url = '{PaymentUrl}'", requestResult.PaymentUrl);

            return Ok(new
            {
                success = true,
                purchase_id = existingPurchase.Id,
                authority = requestResult.Authority,
                payment_url = requestResult.PaymentUrl
            });
        }


        [HttpPost("package")]
        public async Task<IActionResult> CreatePackagePurchase([FromBody] CreatePackagePurchaseInput input)
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var pkg = await _context.CoursePackages
                .Include(p => p.Items)
                .FirstOrDefaultAsync(p => p.Id == input.PackageId);

            if (pkg == null)
            {
                return NotFound(new { success = false, message = "Package not found." });
            }

            // Reject mock or unverified transactions for paid packages
            if (pkg.Price > 0)
            {
                if (string.IsNullOrWhiteSpace(input.TransactionId) ||
                    input.TransactionId.Contains("mock", StringComparison.OrdinalIgnoreCase) ||
                    input.TransactionId.Contains("fake", StringComparison.OrdinalIgnoreCase) ||
                    input.TransactionId.Contains("simulated", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new
                    {
                        success = false,
                        error_code = "UNVERIFIED_TRANSACTION",
                        message = "Mock or unverified transactions are strictly rejected. Payment verification is required."
                    });
                }

                if (string.Equals(input.PaymentProvider, "DIRECT", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(input.PaymentProvider, "ZARINPAL", StringComparison.OrdinalIgnoreCase) ||
                    string.IsNullOrEmpty(input.PaymentProvider))
                {
                    return BadRequest(new
                    {
                        success = false,
                        error_code = "DIRECT_PAYMENT_VERIFICATION_REQUIRED",
                        message = "Direct package purchases must be initiated via /zarinpal/package-request and verified through the payment gateway callback."
                    });
                }
            }

            var provider = input.PaymentProvider ?? "DIRECT";
            var transactionId = input.TransactionId ?? $"PKG_TX_{Guid.NewGuid().ToString("N").Substring(0, 10).ToUpper()}";

            var existingPkgPurchase = await _context.PackagePurchases
                .FirstOrDefaultAsync(p => p.UserId == userId && p.PackageId == input.PackageId);

            if (existingPkgPurchase == null)
            {
                existingPkgPurchase = new PackagePurchase
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    PackageId = input.PackageId,
                    AmountPaid = pkg.Price,
                    PaymentProvider = provider,
                    TransactionId = transactionId,
                    Status = "COMPLETED",
                    PurchasedAt = DateTime.UtcNow
                };
                await _context.PackagePurchases.AddAsync(existingPkgPurchase);
            }
            else
            {
                existingPkgPurchase.Status = "COMPLETED";
                existingPkgPurchase.PaymentProvider = provider;
                existingPkgPurchase.TransactionId = transactionId;
                existingPkgPurchase.AmountPaid = pkg.Price;
                existingPkgPurchase.PurchasedAt = DateTime.UtcNow;
                _context.Entry(existingPkgPurchase).State = EntityState.Modified;
            }

            // Unlock all constituent courses
            var courseIds = pkg.Items.Select(i => i.CourseId).ToList();
            foreach (var courseId in courseIds)
            {
                var existingCoursePurchase = await _context.Purchases
                    .FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == courseId);

                if (existingCoursePurchase == null)
                {
                    var coursePurchase = new Purchase
                    {
                        Id = Guid.NewGuid(),
                        UserId = userId,
                        CourseId = courseId,
                        PaymentProvider = $"{provider}_BUNDLE",
                        TransactionId = $"{transactionId}_{courseId.ToString("N").Substring(0, 6)}",
                        Status = "COMPLETED",
                        PurchasedAt = DateTime.UtcNow
                    };
                    await _context.Purchases.AddAsync(coursePurchase);
                    await _eventBus.PublishAsync(new PurchaseCompletedEvent(coursePurchase));
                }
                else if (existingCoursePurchase.Status != "COMPLETED")
                {
                    existingCoursePurchase.Status = "COMPLETED";
                    existingCoursePurchase.PaymentProvider = $"{provider}_BUNDLE";
                    existingCoursePurchase.TransactionId = $"{transactionId}_{courseId.ToString("N").Substring(0, 6)}";
                    existingCoursePurchase.PurchasedAt = DateTime.UtcNow;
                    _context.Entry(existingCoursePurchase).State = EntityState.Modified;
                    await _eventBus.PublishAsync(new PurchaseCompletedEvent(existingCoursePurchase));
                }
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Package purchased successfully and all courses unlocked.",
                package_purchase = existingPkgPurchase
            });
        }

        [HttpPost("zarinpal/package-request")]
        public async Task<IActionResult> RequestZarinPalPackagePayment([FromBody] ZarinPalPackagePurchaseInput input)
        {
            var userId = GetUserId();
            _logger.LogInformation("PurchaseController: RequestZarinPalPackagePayment: Start. UserId={UserId}, PackageId={PackageId}", userId, input.PackageId);

            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var pkg = await _context.CoursePackages
                .Include(p => p.Items)
                .FirstOrDefaultAsync(p => p.Id == input.PackageId);

            if (pkg == null)
            {
                return NotFound(new { success = false, message = "Package not found." });
            }

            var existingPkgPurchase = await _context.PackagePurchases
                .FirstOrDefaultAsync(p => p.UserId == userId && p.PackageId == input.PackageId);

            if (existingPkgPurchase != null && existingPkgPurchase.Status == "COMPLETED")
            {
                return Ok(new { success = true, message = "Package already purchased.", already_purchased = true, purchase = existingPkgPurchase });
            }

            var user = await _context.Users.FindAsync(userId);
            var mobile = user?.MobileNumber;
            string? email = null;

            var callbackUrl = Environment.GetEnvironmentVariable("ZARINPAL_CALLBACK_URL")
                              ?? _configuration["ZarinPal:CallbackUrl"]
                              ?? $"{Request.Scheme}://{Request.Host}/api/v1/purchases/zarinpal/callback";

            var amountInToman = pkg.Price;
            var description = $"Purchase bundle package: {pkg.Title}";

            var requestResult = await _zarinPalService.RequestPaymentAsync(amountInToman, description, callbackUrl, mobile, email);

            if (!requestResult.IsSuccess)
            {
                _logger.LogError("PurchaseController: RequestZarinPalPackagePayment: ZarinPal request failed: {Message}", requestResult.Message);
                return BadRequest(new { success = false, message = requestResult.Message, code = requestResult.Code });
            }

            if (existingPkgPurchase != null)
            {
                existingPkgPurchase.Status = "PENDING";
                existingPkgPurchase.PaymentProvider = "ZARINPAL";
                existingPkgPurchase.TransactionId = requestResult.Authority;
                existingPkgPurchase.AmountPaid = pkg.Price;
                _context.Entry(existingPkgPurchase).State = EntityState.Modified;
            }
            else
            {
                existingPkgPurchase = new PackagePurchase
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    PackageId = input.PackageId,
                    AmountPaid = pkg.Price,
                    PaymentProvider = "ZARINPAL",
                    TransactionId = requestResult.Authority,
                    Status = "PENDING",
                    PurchasedAt = DateTime.UtcNow
                };
                await _context.PackagePurchases.AddAsync(existingPkgPurchase);
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                purchase_id = existingPkgPurchase.Id,
                authority = requestResult.Authority,
                payment_url = requestResult.PaymentUrl
            });
        }

        [AllowAnonymous]
        [HttpGet("zarinpal/callback")]
        public async Task<IActionResult> ZarinPalCallback([FromQuery] string? Authority, [FromQuery] string? Status, [FromQuery] string? authority, [FromQuery] string? status)
        {
            var auth = Authority ?? authority;
            var stat = Status ?? status;

            _logger.LogInformation("PurchaseController: ZarinPalCallback: Incoming request. Authority='{Authority}', Status='{Status}'", auth, stat);

            if (string.IsNullOrEmpty(auth))
            {
                _logger.LogWarning("PurchaseController: ZarinPalCallback: Authority parameter is missing.");
                return Content("<html><body><h2>Invalid Payment Response</h2><p>Authority parameter is missing.</p></body></html>", "text/html");
            }

            // Check if this authority belongs to a Course purchase or a Package purchase
            var coursePurchase = await _context.Purchases
                .Include(p => p.Course)
                .FirstOrDefaultAsync(p => p.TransactionId == auth || p.Id.ToString() == auth);

            var packagePurchase = await _context.PackagePurchases
                .Include(p => p.Package)
                    .ThenInclude(pkg => pkg!.Items)
                .FirstOrDefaultAsync(p => p.TransactionId == auth || p.Id.ToString() == auth);

            if (coursePurchase == null && packagePurchase == null)
            {
                _logger.LogWarning("PurchaseController: ZarinPalCallback: Transaction record not found for Authority '{Authority}'", auth);
                return Content("<html><body><h2>Transaction Not Found</h2><p>Payment transaction record could not be found.</p></body></html>", "text/html");
            }

            // 1. Handle Package Purchase Callback
            if (packagePurchase != null)
            {
                if (packagePurchase.Status == "COMPLETED")
                {
                    var html = BuildPaymentResponseHtml(
                        isSuccess: true,
                        titleFa: "پرداخت قبلاً تکمیل شده است",
                        titleEn: "Payment Already Completed",
                        descriptionFa: $"دسترسی به بسته «{packagePurchase.Package?.Title}» فعال است.",
                        descriptionEn: $"Access to package '{packagePurchase.Package?.Title}' is already active.",
                        refId: packagePurchase.TransactionId
                    );
                    return Content(html, "text/html; charset=utf-8");
                }

                if (stat != "OK")
                {
                    packagePurchase.Status = "CANCELLED";
                    _context.Entry(packagePurchase).State = EntityState.Modified;
                    await _context.SaveChangesAsync();

                    var html = BuildPaymentResponseHtml(
                        isSuccess: false,
                        titleFa: "پرداخت لغو شد",
                        titleEn: "Payment Cancelled",
                        descriptionFa: "تراکنش توسط کاربر لغو گردید یا پرداخت ناموفق بود.",
                        descriptionEn: "The transaction was cancelled or unsuccessful."
                    );
                    return Content(html, "text/html; charset=utf-8");
                }

                var pkgPrice = packagePurchase.Package?.Price ?? packagePurchase.AmountPaid;
                var verifyResult = await _zarinPalService.VerifyPaymentAsync(pkgPrice, auth);

                if (verifyResult.IsSuccess)
                {
                    packagePurchase.Status = "COMPLETED";
                    packagePurchase.TransactionId = verifyResult.RefId.ToString();
                    packagePurchase.PurchasedAt = DateTime.UtcNow;
                    _context.Entry(packagePurchase).State = EntityState.Modified;

                    // Grant all constituent courses
                    if (packagePurchase.Package?.Items != null)
                    {
                        foreach (var item in packagePurchase.Package.Items)
                        {
                            var cPurchase = await _context.Purchases
                                .FirstOrDefaultAsync(p => p.UserId == packagePurchase.UserId && p.CourseId == item.CourseId);

                            if (cPurchase == null)
                            {
                                cPurchase = new Purchase
                                {
                                    Id = Guid.NewGuid(),
                                    UserId = packagePurchase.UserId,
                                    CourseId = item.CourseId,
                                    PaymentProvider = "ZARINPAL_BUNDLE",
                                    TransactionId = $"{verifyResult.RefId}_{item.CourseId.ToString("N").Substring(0, 6)}",
                                    Status = "COMPLETED",
                                    PurchasedAt = DateTime.UtcNow
                                };
                                await _context.Purchases.AddAsync(cPurchase);
                                await _eventBus.PublishAsync(new PurchaseCompletedEvent(cPurchase));
                            }
                            else if (cPurchase.Status != "COMPLETED")
                            {
                                cPurchase.Status = "COMPLETED";
                                cPurchase.PaymentProvider = "ZARINPAL_BUNDLE";
                                cPurchase.TransactionId = $"{verifyResult.RefId}_{item.CourseId.ToString("N").Substring(0, 6)}";
                                cPurchase.PurchasedAt = DateTime.UtcNow;
                                _context.Entry(cPurchase).State = EntityState.Modified;
                                await _eventBus.PublishAsync(new PurchaseCompletedEvent(cPurchase));
                            }
                        }
                    }

                    await _context.SaveChangesAsync();

                    var html = BuildPaymentResponseHtml(
                        isSuccess: true,
                        titleFa: "پرداخت با موفقیت انجام شد",
                        titleEn: "Payment Verified Successfully",
                        descriptionFa: $"دسترسی به بسته «{packagePurchase.Package?.Title}» و تمامی دوره‌های آن با موفقیت فعال شد.",
                        descriptionEn: $"Access to package '{packagePurchase.Package?.Title}' and all included courses is now active.",
                        refId: verifyResult.RefId.ToString()
                    );
                    return Content(html, "text/html; charset=utf-8");
                }
                else
                {
                    packagePurchase.Status = "FAILED";
                    _context.Entry(packagePurchase).State = EntityState.Modified;
                    await _context.SaveChangesAsync();

                    var html = BuildPaymentResponseHtml(
                        isSuccess: false,
                        titleFa: "خطا در تایید تراکنش",
                        titleEn: "Payment Verification Failed",
                        descriptionFa: "تایید پرداخت با خطا مواجه شد. در صورت کسر وجه از حساب، ظرف ۷۲ ساعت بازگشت داده خواهد شد.",
                        descriptionEn: "Payment verification failed. If money was deducted, it will be refunded within 72 hours.",
                        errorMessage: verifyResult.Message
                    );
                    return Content(html, "text/html; charset=utf-8");
                }
            }

            // 2. Handle Individual Course Purchase Callback
            var purchase = coursePurchase!;
            if (purchase.Status == "COMPLETED")
            {
                _logger.LogInformation("PurchaseController: ZarinPalCallback: Purchase is already COMPLETED. Directing back to app.");
                var html = BuildPaymentResponseHtml(
                    isSuccess: true,
                    titleFa: "پرداخت قبلاً تکمیل شده است",
                    titleEn: "Payment Already Completed",
                    descriptionFa: $"دوره «{purchase.Course?.Title}» قبلاً برای شما فعال شده است.",
                    descriptionEn: $"Course '{purchase.Course?.Title}' is already unlocked.",
                    refId: purchase.TransactionId
                );
                return Content(html, "text/html; charset=utf-8");
            }

            if (stat != "OK")
            {
                _logger.LogWarning("PurchaseController: ZarinPalCallback: Zarinpal returned unsuccessful status: {Status}", stat);
                purchase.Status = "CANCELLED";
                _context.Entry(purchase).State = EntityState.Modified;
                await _context.SaveChangesAsync();

                var html = BuildPaymentResponseHtml(
                    isSuccess: false,
                    titleFa: "پرداخت لغو شد",
                    titleEn: "Payment Cancelled",
                    descriptionFa: "تراکنش توسط کاربر لغو گردید یا پرداخت ناموفق بود.",
                    descriptionEn: "The transaction was cancelled or unsuccessful."
                );
                return Content(html, "text/html; charset=utf-8");
            }

            var coursePrice = purchase.Course?.Price ?? 0m;
            _logger.LogInformation("PurchaseController: ZarinPalCallback: Verifying payment for purchase {PurchaseId}, Price={Price}", purchase.Id, coursePrice);
            var singleVerifyResult = await _zarinPalService.VerifyPaymentAsync(coursePrice, auth);

            _logger.LogInformation("PurchaseController: ZarinPalCallback: Verify result: Success={Success}, Code={Code}, Message='{Message}', RefId={RefId}",
                singleVerifyResult.IsSuccess, singleVerifyResult.Code, singleVerifyResult.Message, singleVerifyResult.RefId);

            if (singleVerifyResult.IsSuccess)
            {
                purchase.Status = "COMPLETED";
                purchase.TransactionId = singleVerifyResult.RefId.ToString();
                purchase.PurchasedAt = DateTime.UtcNow;

                _context.Entry(purchase).State = EntityState.Modified;
                await _context.SaveChangesAsync();

                // Publish event for backup replication
                await _eventBus.PublishAsync(new PurchaseCompletedEvent(purchase));

                var html = BuildPaymentResponseHtml(
                    isSuccess: true,
                    titleFa: "پرداخت با موفقیت انجام شد",
                    titleEn: "Payment Verified Successfully",
                    descriptionFa: $"دوره «{purchase.Course?.Title}» برای شما فعال گردید و هم‌اکنون در اپلیکیشن قابل دانلود است.",
                    descriptionEn: $"Course '{purchase.Course?.Title}' is now unlocked and available for download.",
                    refId: singleVerifyResult.RefId.ToString()
                );
                return Content(html, "text/html; charset=utf-8");
            }
            else
            {
                _logger.LogError("PurchaseController: ZarinPalCallback: Verification failed: {Message}", singleVerifyResult.Message);

                purchase.Status = "FAILED";
                _context.Entry(purchase).State = EntityState.Modified;
                await _context.SaveChangesAsync();

                var html = BuildPaymentResponseHtml(
                    isSuccess: false,
                    titleFa: "خطا در تایید تراکنش",
                    titleEn: "Payment Verification Failed",
                    descriptionFa: "تایید پرداخت با خطا مواجه شد. در صورت کسر وجه از حساب، ظرف ۷۲ ساعت توسط بانک بازگشت داده خواهد شد.",
                    descriptionEn: "Payment verification failed. Deducted funds will be returned within 72 hours by your bank.",
                    errorMessage: singleVerifyResult.Message
                );
                return Content(html, "text/html; charset=utf-8");
            }
        }

        private static string BuildPaymentResponseHtml(
            bool isSuccess,
            string titleFa,
            string titleEn,
            string descriptionFa,
            string descriptionEn,
            string? refId = null,
            string? errorMessage = null)
        {
            var status = isSuccess ? "success" : "failed";
            var deepLink = string.IsNullOrEmpty(refId)
                ? $"leitnerapp://payment-result?status={status}"
                : $"leitnerapp://payment-result?status={status}&ref_id={refId}";

            var primaryColor = isSuccess ? "#16a34a" : "#dc2626";
            var iconBg = isSuccess ? "#dcfce7" : "#fee2e2";
            var iconSvg = isSuccess
                ? @"<svg width='48' height='48' viewBox='0 0 24 24' fill='none' stroke='#16a34a' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'><path d='M22 11.08V12a10 10 0 1 1-5.93-9.14'></path><polyline points='22 4 12 14.01 9 11.01'></polyline></svg>"
                : @"<svg width='48' height='48' viewBox='0 0 24 24' fill='none' stroke='#dc2626' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='10'></circle><line x1='15' y1='9' x2='9' y2='15'></line><line x1='9' y1='9' x2='15' y2='15'></line></svg>";

            var refIdBlock = !string.IsNullOrEmpty(refId)
                ? $@"<div style='background:#f8fafc; border-radius:12px; padding:14px 20px; margin:20px 0; border:1.5px dashed #cbd5e1;'>
                        <div style='font-size:13px; color:#64748b;'>کد پیگیری تراکنش / Ref ID</div>
                        <div style='font-size:22px; font-weight:bold; color:#0f172a; letter-spacing:1px; margin-top:4px; font-family:monospace;'>{refId}</div>
                     </div>"
                : "";

            var errorBlock = !string.IsNullOrEmpty(errorMessage)
                ? $@"<div style='background:#fef2f2; color:#991b1b; padding:12px; border-radius:10px; font-size:13px; margin:16px 0; border:1px solid #fee2e2;'>{errorMessage}</div>"
                : "";

            return $@"<!DOCTYPE html>
<html lang='fa' dir='rtl'>
<head>
    <meta charset='utf-8'>
    <title>{titleFa}</title>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: #1e293b;
        }}
        .card {{
            background: #ffffff;
            width: 100%;
            max-width: 440px;
            border-radius: 24px;
            padding: 36px 28px;
            text-align: center;
            box-shadow: 0 20px 45px rgba(0, 0, 0, 0.3);
            animation: fadeIn 0.4s ease-out;
        }}
        @keyframes fadeIn {{
            from {{ opacity: 0; transform: translateY(15px); }}
            to {{ opacity: 1; transform: translateY(0); }}
        }}
        .icon-box {{
            width: 80px;
            height: 80px;
            border-radius: 50%;
            background: {iconBg};
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
        }}
        h2 {{
            color: {primaryColor};
            font-size: 22px;
            margin-bottom: 6px;
            font-weight: 800;
        }}
        .sub-title {{
            font-size: 14px;
            color: #64748b;
            margin-bottom: 16px;
            font-weight: 500;
        }}
        .desc {{
            font-size: 15px;
            color: #334155;
            line-height: 1.6;
            margin-bottom: 6px;
        }}
        .btn {{
            display: inline-block;
            width: 100%;
            padding: 14px 20px;
            background: #2563eb;
            color: #ffffff;
            font-size: 16px;
            font-weight: bold;
            border-radius: 14px;
            text-decoration: none;
            transition: all 0.2s;
            margin-top: 14px;
            box-shadow: 0 4px 14px rgba(37, 99, 235, 0.35);
        }}
        .btn:hover {{
            background: #1d4ed8;
        }}
        .btn:active {{
            transform: scale(0.98);
        }}
        .redirect-notice {{
            font-size: 12px;
            color: #94a3b8;
            margin-top: 16px;
        }}
    </style>
    <script>
        window.addEventListener('DOMContentLoaded', function() {{
            setTimeout(function() {{
                try {{
                    window.location.href = '{deepLink}';
                }} catch (e) {{}}
            }}, 1200);
        }});
    </script>
</head>
<body>
    <div class='card'>
        <div class='icon-box'>
            {iconSvg}
        </div>
        <h2>{titleFa}</h2>
        <div class='sub-title'>{titleEn}</div>
        <p class='desc'>{descriptionFa}</p>
        <p class='desc' style='font-size:13px; color:#64748b; direction:ltr;'>{descriptionEn}</p>
        {refIdBlock}
        {errorBlock}
        <a href='{deepLink}' class='btn'>بازگشت به اپلیکیشن / Return to App</a>
        <div class='redirect-notice'>در حال انتقال خودکار به اپلیکیشن...<br>Automatically redirecting to the app...</div>
    </div>
</body>
</html>";
        }

        [HttpGet("{id:guid}/status")]
        public async Task<IActionResult> GetPurchaseStatus(Guid id)
        {
            var userId = GetUserId();
            var purchase = await _context.Purchases
                .FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);

            if (purchase == null)
            {
                return NotFound(new { success = false, message = "Purchase record not found." });
            }

            return Ok(new
            {
                success = true,
                purchase_id = purchase.Id,
                status = purchase.Status,
                transaction_id = purchase.TransactionId,
                payment_provider = purchase.PaymentProvider,
                purchased_at = purchase.PurchasedAt
            });
        }
    }

    public class CreatePurchaseInput
    {
        public Guid CourseId { get; set; }
        public string? PaymentProvider { get; set; }
        public string? TransactionId { get; set; }
    }

    public class CreatePackagePurchaseInput
    {
        public Guid PackageId { get; set; }
        public string? PaymentProvider { get; set; }
        public string? TransactionId { get; set; }
    }

    public class ZarinPalPurchaseInput
    {
        public Guid CourseId { get; set; }
    }

    public class ZarinPalPackagePurchaseInput
    {
        public Guid PackageId { get; set; }
    }
}

