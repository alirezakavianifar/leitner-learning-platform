using System;

namespace LeitnerPlatform.Core.Entities
{
    public class LeitnerProgress
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public Guid CardId { get; set; }
        public int CurrentBox { get; set; } = 1;
        public DateTime? LastReviewedAt { get; set; }
        public DateTime? NextReviewDue { get; set; }

        public User? User { get; set; }
        public Card? Card { get; set; }
    }
}
