using System;

namespace LeitnerPlatform.Core.Events
{
    public class CardFinishedEvent
    {
        public Guid UserId { get; }
        public Guid CourseId { get; }
        public int CardNumber { get; }
        public DateTime FinishedAt { get; }

        public CardFinishedEvent(Guid userId, Guid courseId, int cardNumber, DateTime finishedAt)
        {
            UserId = userId;
            CourseId = courseId;
            CardNumber = cardNumber;
            FinishedAt = finishedAt;
        }
    }
}
