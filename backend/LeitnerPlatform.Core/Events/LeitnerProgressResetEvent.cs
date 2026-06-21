using System;

namespace LeitnerPlatform.Core.Events
{
    public class LeitnerProgressResetEvent
    {
        public Guid UserId { get; }
        public Guid CourseId { get; }
        public int CardNumber { get; }
        public DateTime ResetAt { get; }
        public string Reason { get; }

        public LeitnerProgressResetEvent(Guid userId, Guid courseId, int cardNumber, DateTime resetAt, string reason)
        {
            UserId = userId;
            CourseId = courseId;
            CardNumber = cardNumber;
            ResetAt = resetAt;
            Reason = reason;
        }
    }
}
