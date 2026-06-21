using System.Threading.Tasks;

namespace LeitnerPlatform.Core.Interfaces
{
      public interface ISmsService
      {
          Task<bool> SendOtpAsync(string mobileNumber, string code);
      }
}
