using System;
using System.Net.Http;
using System.Threading.Tasks;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Services
{
    public class SmsService : ISmsService
    {
        private readonly HttpClient _httpClient;

        public SmsService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<bool> SendOtpAsync(string mobileNumber, string code)
        {
            var apiKey = Environment.GetEnvironmentVariable("SMS_GATEWAY_API_KEY");
            if (string.IsNullOrEmpty(apiKey))
            {
                // Local dev bypass/fallback: log code to console
                Console.WriteLine($"[SMS Bypass] SMS code for {mobileNumber} is: {code}");
                return true;
            }

            try
            {
                // Kavenegar lookup URL format: https://api.kavenegar.com/v1/{apikey}/verify/lookup.json
                var url = $"https://api.kavenegar.com/v1/{apiKey}/verify/lookup.json?receptor={mobileNumber}&token={code}&template=otp-template";
                
                Console.WriteLine($"Sending OTP SMS via Kavenegar to {mobileNumber}...");
                var response = await _httpClient.PostAsync(url, null);

                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"OTP SMS sent successfully to {mobileNumber}.");
                    return true;
                }

                var content = await response.Content.ReadAsStringAsync();
                Console.WriteLine($"Kavenegar returned failure status: {response.StatusCode}, Content: {content}");
                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending SMS via Kavenegar: {ex.Message}");
                // Log and return true so development isn't blocked by network errors
                return true;
            }
        }
    }
}
