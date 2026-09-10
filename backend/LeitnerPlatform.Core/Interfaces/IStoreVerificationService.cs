using System.Threading.Tasks;

namespace LeitnerPlatform.Core.Interfaces
{
    public class StoreVerificationResult
    {
        public bool IsValid { get; set; }
        public string Message { get; set; } = string.Empty;
        public string? PurchaseToken { get; set; }
        public string? OrderId { get; set; }
    }

    public interface IStoreVerificationService
    {
        Task<StoreVerificationResult> VerifyPurchaseAsync(string provider, string productId, string purchaseToken);
    }
}
