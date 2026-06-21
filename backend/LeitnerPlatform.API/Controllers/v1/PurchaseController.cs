using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Data;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using System.Security.Claims;

namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize]
    [ApiController]
    [Route("api/v1/purchases")]
    public class PurchaseController : ControllerBase
    {
        private readonly LeitnerDbContext _context;
        private readonly IEventBus _eventBus;

        public PurchaseController(LeitnerDbContext context, IEventBus eventBus)
        {
            _context = context;
            _eventBus = eventBus;
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
    }

    public class CreatePurchaseInput
    {
        public Guid CourseId { get; set; }
        public string? PaymentProvider { get; set; }
        public string? TransactionId { get; set; }
    }
}
