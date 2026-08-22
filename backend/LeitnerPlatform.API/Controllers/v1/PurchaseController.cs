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
                    var successHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Successful</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#2e7d32;'>Payment Completed</h2>
    <p>Your package <strong>{packagePurchase.Package?.Title}</strong> has already been unlocked!</p>
    <p>Ref ID: <code>{packagePurchase.TransactionId}</code></p>
    <a href='leitnerapp://payment-result?status=success&ref_id={packagePurchase.TransactionId}' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#1976d2; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                    return Content(successHtml, "text/html");
                }

                if (stat != "OK")
                {
                    packagePurchase.Status = "CANCELLED";
                    _context.Entry(packagePurchase).State = EntityState.Modified;
                    await _context.SaveChangesAsync();

                    var cancelHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Cancelled</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#c62828;'>Payment Cancelled</h2>
    <p>The transaction was cancelled or unsuccessful.</p>
    <a href='leitnerapp://payment-result?status=cancelled' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#757575; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                    return Content(cancelHtml, "text/html");
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

                    var successHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Successful</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#2e7d32;'>Payment Verified Successfully</h2>
    <p>Thank you! Access to package <strong>{packagePurchase.Package?.Title}</strong> and all its courses is now active.</p>
    <p>Reference Code (RefID): <strong style='font-size:18px; color:#1565c0;'>{verifyResult.RefId}</strong></p>
    <a href='leitnerapp://payment-result?status=success&ref_id={verifyResult.RefId}' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#1976d2; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                    return Content(successHtml, "text/html");
                }
                else
                {
                    packagePurchase.Status = "FAILED";
                    _context.Entry(packagePurchase).State = EntityState.Modified;
                    await _context.SaveChangesAsync();

                    var failHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Verification Failed</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#c62828;'>Payment Verification Failed</h2>
    <p>{verifyResult.Message}</p>
    <a href='leitnerapp://payment-result?status=failed' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#757575; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                    return Content(failHtml, "text/html");
                }
            }

            // 2. Handle Individual Course Purchase Callback
            var purchase = coursePurchase!;
            if (purchase.Status == "COMPLETED")
            {
                _logger.LogInformation("PurchaseController: ZarinPalCallback: Purchase is already COMPLETED. Directing back to app.");
                var successHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Successful</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#2e7d32;'>Payment Completed</h2>
    <p>Your course <strong>{purchase.Course?.Title}</strong> has already been unlocked!</p>
    <p>Ref ID: <code>{purchase.TransactionId}</code></p>
    <a href='leitnerapp://payment-result?status=success&ref_id={purchase.TransactionId}' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#1976d2; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                return Content(successHtml, "text/html");
            }

            if (stat != "OK")
            {
                _logger.LogWarning("PurchaseController: ZarinPalCallback: Zarinpal returned unsuccessful status: {Status}", stat);
                purchase.Status = "CANCELLED";
                _context.Entry(purchase).State = EntityState.Modified;
                await _context.SaveChangesAsync();

                var cancelHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Cancelled</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#c62828;'>Payment Cancelled</h2>
    <p>The transaction was cancelled or unsuccessful.</p>
    <a href='leitnerapp://payment-result?status=cancelled' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#757575; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                return Content(cancelHtml, "text/html");
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

                var successHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Successful</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#2e7d32;'>Payment Verified Successfully</h2>
    <p>Thank you! Access to <strong>{purchase.Course?.Title}</strong> is now active.</p>
    <p>Reference Code (RefID): <strong style='font-size:18px; color:#1565c0;'>{singleVerifyResult.RefId}</strong></p>
    <a href='leitnerapp://payment-result?status=success&ref_id={singleVerifyResult.RefId}' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#1976d2; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                return Content(successHtml, "text/html");
            }
            else
            {
                _logger.LogError("PurchaseController: ZarinPalCallback: Verification failed: {Message}", singleVerifyResult.Message);

                purchase.Status = "FAILED";
                _context.Entry(purchase).State = EntityState.Modified;
                await _context.SaveChangesAsync();

                var failHtml = $@"<!DOCTYPE html>
<html>
<head><title>Payment Verification Failed</title><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='font-family:sans-serif; text-align:center; padding:40px; background:#f4f6f9;'>
  <div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color:#c62828;'>Payment Verification Failed</h2>
    <p>{singleVerifyResult.Message}</p>
    <a href='leitnerapp://payment-result?status=failed' style='display:inline-block; margin-top:20px; padding:10px 20px; background:#757575; color:white; border-radius:6px; text-decoration:none;'>Return to App</a>
  </div>
</body>
</html>";
                return Content(failHtml, "text/html");
            }
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

