using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;

namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize]
    [ApiController]
    [Route("api/v1/statistics")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class StatisticsController : ControllerBase
    {
        private readonly LeitnerDbContext _context;
        private readonly IEventBus _eventBus;

        public StatisticsController(LeitnerDbContext context, IEventBus eventBus)
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

        [HttpPost("sync")]
        public async Task<IActionResult> SyncProgress([FromBody] ProgressSyncInput input)
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            if (input == null || input.ProgressDeltas == null)
            {
                return BadRequest(new { success = false, message = "Invalid sync payload." });
            }

            var processedCount = 0;

            foreach (var delta in input.ProgressDeltas)
            {
                // Verify purchase access: either the course is free or user has purchased it.
                var course = await _context.Courses.FindAsync(delta.CourseId);
                if (course == null)
                {
                    continue; // Skip if course doesn't exist
                }

                var hasAccess = course.Price == 0 || await _context.Purchases.AnyAsync(p => 
                    p.UserId == userId && p.CourseId == delta.CourseId && p.Status == "COMPLETED");

                if (!hasAccess)
                {
                    continue; // Skip if user does not have purchase access to the course
                }

                // Find card in course by number
                var card = await _context.Cards
                    .FirstOrDefaultAsync(c => c.CourseId == delta.CourseId && c.CardNumber == delta.CardNumber);

                if (card == null)
                {
                    continue; // Skip if card doesn't exist in the course database
                }

                // Check existing progress
                var progress = await _context.LeitnerProgresses
                    .FirstOrDefaultAsync(p => p.UserId == userId && p.CardId == card.Id);

                bool isNew = progress == null;
                bool shouldUpdate = isNew;

                if (progress != null && delta.LastReviewedAt.HasValue)
                {
                    // Conflict resolution: only update if delta's review timestamp is strictly newer
                    shouldUpdate = !progress.LastReviewedAt.HasValue || delta.LastReviewedAt.Value > progress.LastReviewedAt.Value;
                }

                if (shouldUpdate)
                {
                    if (isNew)
                    {
                        progress = new LeitnerProgress
                        {
                            Id = Guid.NewGuid(),
                            UserId = userId,
                            CardId = card.Id,
                            CurrentBox = delta.CurrentBox,
                            LastReviewedAt = delta.LastReviewedAt,
                            NextReviewDue = delta.NextReviewDue
                        };
                        await _context.LeitnerProgresses.AddAsync(progress);
                    }
                    else
                    {
                        progress!.CurrentBox = delta.CurrentBox;
                        progress.LastReviewedAt = delta.LastReviewedAt;
                        progress.NextReviewDue = delta.NextReviewDue;
                        _context.LeitnerProgresses.Update(progress);
                    }

                    processedCount++;

                    // Emit backend events based on the sync trigger
                    var eventTime = delta.LastReviewedAt ?? DateTime.UtcNow;
                    var trigger = delta.Trigger?.ToUpperInvariant();

                    if (trigger == "REVIEW_CORRECT")
                    {
                        if (delta.CurrentBox == 6)
                        {
                            await _eventBus.PublishAsync(new CardFinishedEvent(userId, delta.CourseId, delta.CardNumber, eventTime));
                        }
                        else
                        {
                            await _eventBus.PublishAsync(new CardReviewedEvent(userId, delta.CourseId, delta.CardNumber, delta.CurrentBox, eventTime));
                        }
                    }
                    else if (trigger == "REVIEW_INCORRECT")
                    {
                        await _eventBus.PublishAsync(new CardReviewedEvent(userId, delta.CourseId, delta.CardNumber, 1, eventTime));
                    }
                    else if (trigger == "OVERDUE_RESET")
                    {
                        await _eventBus.PublishAsync(new DueDateOverdueResetEvent(userId, delta.CourseId, delta.CardNumber, eventTime));
                    }
                    else if (trigger == "FAVORITES_RESET" || trigger == "JUMP_RESET")
                    {
                        await _eventBus.PublishAsync(new LeitnerProgressResetEvent(userId, delta.CourseId, delta.CardNumber, eventTime, trigger));
                    }
                }
            }

            if (processedCount > 0)
            {
                await _context.SaveChangesAsync();
            }

            return Ok(new
            {
                success = true,
                processed_count = processedCount,
                message = "Progress synchronized successfully."
            });
        }
    }

    public class ProgressSyncInput
    {
        [JsonPropertyName("sync_time")]
        public DateTime SyncTime { get; set; }

        [JsonPropertyName("progress_deltas")]
        public List<ProgressDeltaInput> ProgressDeltas { get; set; } = new();
    }

    public class ProgressDeltaInput
    {
        [JsonPropertyName("course_id")]
        public Guid CourseId { get; set; }

        [JsonPropertyName("card_number")]
        public int CardNumber { get; set; }

        [JsonPropertyName("current_box")]
        public int CurrentBox { get; set; }

        [JsonPropertyName("last_reviewed_at")]
        public DateTime? LastReviewedAt { get; set; }

        [JsonPropertyName("next_review_due")]
        public DateTime? NextReviewDue { get; set; }

        [JsonPropertyName("trigger")]
        public string? Trigger { get; set; }
    }
}
