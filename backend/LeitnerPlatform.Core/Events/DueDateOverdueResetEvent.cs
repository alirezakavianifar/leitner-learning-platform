using System;

namespace LeitnerPlatform.Core.Events
{
    public class DueDateOverdueResetEvent
    {
        public Guid UserId { get; }
        public Guid CourseId { get; }
        public int CardNumber { get; }
        public DateTime ResetAt { get; }

        public DueDateOverdueResetEvent(Guid userId, Guid courseId, int cardNumber, DateTime resetAt)
        {
            UserId = userId;
            CourseId = courseId;
            CardNumber = cardNumber;
            ResetAt = resetAt;
        }
    }
}
