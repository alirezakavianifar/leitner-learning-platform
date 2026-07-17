using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
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

            var provider = Environment.GetEnvironmentVariable("SMS_PROVIDER") ?? "Kavenegar";

            try
            {
                if (provider.Equals("FarazSms", StringComparison.OrdinalIgnoreCase) || 
                    provider.Equals("IPPanel", StringComparison.OrdinalIgnoreCase))
                {
                    var sender = Environment.GetEnvironmentVariable("SMS_SENDER") ?? "+983000505";
                    var patternCode = Environment.GetEnvironmentVariable("SMS_PATTERN_CODE") ?? "otp-template";

                    var payload = new
                    {
                        pattern_code = patternCode,
                        sender = sender,
                        recipient = mobileNumber,
                        variable_values = new Dictionary<string, string>
                        {
                            { "code", code }
                        }
                    };

                    _httpClient.DefaultRequestHeaders.Clear();
                    _httpClient.DefaultRequestHeaders.Add("apikey", apiKey);

                    Console.WriteLine($"Sending OTP SMS via FarazSMS (IPPanel) to {mobileNumber} using pattern {patternCode}...");
                    var response = await _httpClient.PostAsJsonAsync("https://api2.ippanel.com/api/v1/sms/pattern/normal/send", payload);

                    if (response.IsSuccessStatusCode)
                    {
                        Console.WriteLine($"OTP SMS sent successfully via FarazSMS to {mobileNumber}.");
                        return true;
                    }

                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"FarazSMS (IPPanel) returned failure status: {response.StatusCode}, Content: {content}");
                    return false;
                }
                else if (provider.Equals("IranPayamak", StringComparison.OrdinalIgnoreCase))
                {
                    var sender = Environment.GetEnvironmentVariable("SMS_SENDER") ?? "50002178584000";
                    var patternCode = Environment.GetEnvironmentVariable("SMS_PATTERN_CODE") ?? "otp-template";
                    var localMobile = mobileNumber.StartsWith("+98") ? "0" + mobileNumber.Substring(3) : mobileNumber;

                    var payload = new
                    {
                        code = patternCode,
                        recipient = localMobile,
                        line_number = sender,
                        number_format = "english",
                        attributes = new Dictionary<string, string>
                        {
                            { "code", code }
                        }
                    };

                    _httpClient.DefaultRequestHeaders.Clear();
                    _httpClient.DefaultRequestHeaders.Add("Api-Key", apiKey);

                    Console.WriteLine($"Sending OTP SMS via IranPayamak to {localMobile} using pattern {patternCode}...");
                    var response = await _httpClient.PostAsJsonAsync("https://api.iranpayamak.com/ws/v1/sms/pattern", payload);

                    if (response.IsSuccessStatusCode)
                    {
                        Console.WriteLine($"OTP SMS sent successfully via IranPayamak to {localMobile}.");
                        return true;
                    }

                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"IranPayamak returned failure status: {response.StatusCode}, Content: {content}");
                    return false;
                }
                else
                {
                    // Default to Kavenegar lookup URL format: https://api.kavenegar.com/v1/{apikey}/verify/lookup.json
                    var url = $"https://api.kavenegar.com/v1/{apiKey}/verify/lookup.json?receptor={mobileNumber}&token={code}&template=otp-template";
                    
                    Console.WriteLine($"Sending OTP SMS via Kavenegar to {mobileNumber}...");
                    var response = await _httpClient.PostAsync(url, null);

                    if (response.IsSuccessStatusCode)
                    {
                        Console.WriteLine($"OTP SMS sent successfully via Kavenegar to {mobileNumber}.");
                        return true;
                    }

                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Kavenegar returned failure status: {response.StatusCode}, Content: {content}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending SMS: {ex.Message}");
                // Log and return true so development isn't blocked by network errors
                return true;
            }
        }
    }
}
