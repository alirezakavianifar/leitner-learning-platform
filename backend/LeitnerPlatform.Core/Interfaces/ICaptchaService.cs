using System.Threading.Tasks;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface ICaptchaService
    {
        Task<(string Id, string ImageBase64)> GenerateCaptchaAsync();
        Task<bool> ValidateCaptchaAsync(string id, string answer);
    }
}
