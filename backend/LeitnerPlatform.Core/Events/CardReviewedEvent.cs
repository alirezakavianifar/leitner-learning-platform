using System;

namespace LeitnerPlatform.Core.Events
{
    public class CardReviewedEvent
    {
        public Guid UserId { get; }
        public Guid CourseId { get; }
        public int CardNumber { get; }
        public int Box { get; }
        public DateTime ReviewedAt { get; }

        public CardReviewedEvent(Guid userId, Guid courseId, int cardNumber, int box, DateTime reviewedAt)
        {
            UserId = userId;
            CourseId = courseId;
            CardNumber = cardNumber;
            Box = box;
            ReviewedAt = reviewedAt;
        }
    }
}
