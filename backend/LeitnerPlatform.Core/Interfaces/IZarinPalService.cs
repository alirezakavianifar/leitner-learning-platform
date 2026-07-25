using System.Threading.Tasks;

namespace LeitnerPlatform.Core.Interfaces
{
    public class ZarinPalRequestResponse
    {
        public bool IsSuccess { get; set; }
        public int Code { get; set; }
        public string Message { get; set; } = string.Empty;
        public string Authority { get; set; } = string.Empty;
        public string PaymentUrl { get; set; } = string.Empty;
    }

    public class ZarinPalVerifyResponse
    {
        public bool IsSuccess { get; set; }
        public int Code { get; set; }
        public string Message { get; set; } = string.Empty;
        public long RefId { get; set; }
        public string CardPan { get; set; } = string.Empty;
    }

    public interface IZarinPalService
    {
        Task<ZarinPalRequestResponse> RequestPaymentAsync(decimal amountInToman, string description, string callbackUrl, string? mobile = null, string? email = null);
        Task<ZarinPalVerifyResponse> VerifyPaymentAsync(decimal amountInToman, string authority);
    }
}
