using System;

namespace LeitnerPlatform.Core.Entities
{
    public class Purchase
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public Guid CourseId { get; set; }
        public string PaymentProvider { get; set; } = string.Empty;
        public string TransactionId { get; set; } = string.Empty;
        public string Status { get; set; } = "PENDING";
        public DateTime PurchasedAt { get; set; }

        public User? User { get; set; }
        public Course? Course { get; set; }
    }
}
