using System;

namespace LeitnerPlatform.Core.Entities
{
    public class PackagePurchase
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public Guid PackageId { get; set; }
        public decimal AmountPaid { get; set; }
        public string PaymentProvider { get; set; } = string.Empty;
        public string TransactionId { get; set; } = string.Empty;
        public string Status { get; set; } = "PENDING";
        public DateTime PurchasedAt { get; set; } = DateTime.UtcNow;

        public User? User { get; set; }
        public CoursePackage? Package { get; set; }
    }
}
