using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Services
{
    public class ZarinPalService : IZarinPalService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;
        private readonly ILogger<ZarinPalService> _logger;

        public ZarinPalService(HttpClient httpClient, IConfiguration configuration, ILogger<ZarinPalService> logger)
        {
            _httpClient = httpClient;
            _configuration = configuration;
            _logger = logger;
        }

        private string GetMerchantId()
        {
            var merchantId = Environment.GetEnvironmentVariable("ZARINPAL_MERCHANT_ID")
                             ?? _configuration["ZarinPal:MerchantId"];
            var finalMerchant = string.IsNullOrWhiteSpace(merchantId) ? "167ccd1b-f5d3-407d-85d1-a73c4f2ba3eb" : merchantId.Trim();
            _logger.LogInformation("ZarinPal: GetMerchantId returned '{MerchantId}'", finalMerchant);
            return finalMerchant;
        }

        private bool IsSandbox()
        {
            var sandboxEnv = Environment.GetEnvironmentVariable("ZARINPAL_SANDBOX")
                             ?? _configuration["ZarinPal:IsSandbox"];
            var isSandbox = bool.TryParse(sandboxEnv, out var res) && res;
            _logger.LogInformation("ZarinPal: IsSandbox returned {IsSandbox}", isSandbox);
            return isSandbox;
        }

        private string GetBaseApiUrl()
        {
            var url = IsSandbox()
                ? "https://sandbox.zarinpal.com/pg/v4/payment/"
                : "https://api.zarinpal.com/pg/v4/payment/";
            _logger.LogInformation("ZarinPal: GetBaseApiUrl returned '{Url}'", url);
            return url;
        }

        private string GetStartPayUrl(string authority)
        {
            var url = IsSandbox()
                ? $"https://sandbox.zarinpal.com/pg/StartPay/{authority}"
                : $"https://www.zarinpal.com/pg/StartPay/{authority}";
            _logger.LogInformation("ZarinPal: GetStartPayUrl for Authority '{Authority}' returned '{Url}'", authority, url);
            return url;
        }

        public async Task<ZarinPalRequestResponse> RequestPaymentAsync(
            decimal amountInToman,
            string description,
            string callbackUrl,
            string? mobile = null,
            string? email = null)
        {
            var merchantId = GetMerchantId();
            var baseUrl = GetBaseApiUrl();

            var metadata = new Dictionary<string, string>();
            if (!string.IsNullOrWhiteSpace(mobile)) metadata["mobile"] = mobile;
            if (!string.IsNullOrWhiteSpace(email)) metadata["email"] = email;

            // ZarinPal requires minimum 1000 Tomans (10,000 Rials)
            if (amountInToman < 1000m)
            {
                _logger.LogWarning("ZarinPal: Requested amount {Amount} Tomans is lower than minimum 1000 Tomans. Clamping to 1000.", amountInToman);
                amountInToman = 1000m;
            }

            var payload = new
            {
                merchant_id = merchantId,
                amount = (long)amountInToman, // Amount in Toman
                currency = "IRT",
                description = description,
                callback_url = callbackUrl,
                metadata = metadata
            };

            var payloadJson = JsonSerializer.Serialize(payload);
            _logger.LogInformation("ZarinPal: Sending RequestPaymentAsync to '{Url}' with payload: {Payload}", $"{baseUrl}request.json", payloadJson);

            try
            {
                var response = await _httpClient.PostAsJsonAsync($"{baseUrl}request.json", payload);
                _logger.LogInformation("ZarinPal: Request response status: {StatusCode}", response.StatusCode);

                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError("ZarinPal: Request HTTP failed: {ErrorContent}", errorContent);
                    return new ZarinPalRequestResponse
                    {
                        IsSuccess = false,
                        Code = (int)response.StatusCode,
                        Message = $"HTTP request failed with status code {response.StatusCode}: {errorContent}"
                    };
                }

                var json = await response.Content.ReadAsStringAsync();
                _logger.LogInformation("ZarinPal: Request response body: {ResponseBody}", json);

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                if (root.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Object)
                {
                    var code = data.GetProperty("code").GetInt32();
                    var authority = data.GetProperty("authority").GetString() ?? string.Empty;

                    _logger.LogInformation("ZarinPal: Request parsed data code={Code}, authority='{Authority}'", code, authority);

                    if (code == 100 && !string.IsNullOrEmpty(authority))
                    {
                        return new ZarinPalRequestResponse
                        {
                            IsSuccess = true,
                            Code = code,
                            Message = "Payment request created successfully.",
                            Authority = authority,
                            PaymentUrl = GetStartPayUrl(authority)
                        };
                    }

                    var message = data.TryGetProperty("message", out var msgProp) ? msgProp.GetString() : "Request failed";
                    _logger.LogWarning("ZarinPal: Request returned non-100 code. Message={Message}", message);
                    return new ZarinPalRequestResponse
                    {
                        IsSuccess = false,
                        Code = code,
                        Message = message ?? "ZarinPal returned non-100 code."
                    };
                }

                _logger.LogError("ZarinPal: Invalid JSON structure in response.");
                return new ZarinPalRequestResponse
                {
                    IsSuccess = false,
                    Message = "Invalid JSON response structure from ZarinPal."
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ZarinPal: Exception during RequestPaymentAsync");
                return new ZarinPalRequestResponse
                {
                    IsSuccess = false,
                    Message = $"Exception during ZarinPal payment request: {ex.Message}"
                };
            }
        }

        public async Task<ZarinPalVerifyResponse> VerifyPaymentAsync(decimal amountInToman, string authority)
        {
            var merchantId = GetMerchantId();
            var baseUrl = GetBaseApiUrl();

            if (amountInToman < 1000m)
            {
                _logger.LogWarning("ZarinPal: Verify amount {Amount} Tomans is lower than minimum 1000 Tomans. Clamping to 1000.", amountInToman);
                amountInToman = 1000m;
            }

            var payload = new
            {
                merchant_id = merchantId,
                amount = (long)amountInToman,
                authority = authority
            };

            var payloadJson = JsonSerializer.Serialize(payload);
            _logger.LogInformation("ZarinPal: Sending VerifyPaymentAsync to '{Url}' with payload: {Payload}", $"{baseUrl}verify.json", payloadJson);

            try
            {
                var response = await _httpClient.PostAsJsonAsync($"{baseUrl}verify.json", payload);
                _logger.LogInformation("ZarinPal: Verify response status: {StatusCode}", response.StatusCode);

                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError("ZarinPal: Verify HTTP failed: {ErrorContent}", errorContent);
                    return new ZarinPalVerifyResponse
                    {
                        IsSuccess = false,
                        Code = (int)response.StatusCode,
                        Message = $"HTTP request failed with status code {response.StatusCode}: {errorContent}"
                    };
                }

                var json = await response.Content.ReadAsStringAsync();
                _logger.LogInformation("ZarinPal: Verify response body: {ResponseBody}", json);

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                if (root.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Object)
                {
                    var code = data.GetProperty("code").GetInt32();
                    var refId = data.TryGetProperty("ref_id", out var refProp) && refProp.ValueKind == JsonValueKind.Number 
                        ? refProp.GetInt64() 
                        : 0L;
                    var cardPan = data.TryGetProperty("card_pan", out var panProp) ? panProp.GetString() ?? string.Empty : string.Empty;

                    _logger.LogInformation("ZarinPal: Verify parsed data code={Code}, refId={RefId}, cardPan='{CardPan}'", code, refId, cardPan);

                    // Code 100 = First time verification success, Code 101 = Already verified
                    if (code == 100 || code == 101)
                    {
                        return new ZarinPalVerifyResponse
                        {
                            IsSuccess = true,
                            Code = code,
                            Message = code == 100 ? "Payment verified successfully." : "Payment was already verified.",
                            RefId = refId,
                            CardPan = cardPan
                        };
                    }

                    var message = data.TryGetProperty("message", out var msgProp) ? msgProp.GetString() : "Verification failed";
                    _logger.LogWarning("ZarinPal: Verify returned non-100/101 code. Message={Message}", message);
                    return new ZarinPalVerifyResponse
                    {
                        IsSuccess = false,
                        Code = code,
                        Message = message ?? "ZarinPal verification failed."
                    };
                }

                _logger.LogError("ZarinPal: Invalid JSON structure in verify response.");
                return new ZarinPalVerifyResponse
                {
                    IsSuccess = false,
                    Message = "Invalid JSON response structure from ZarinPal verify."
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ZarinPal: Exception during VerifyPaymentAsync");
                return new ZarinPalVerifyResponse
                {
                    IsSuccess = false,
                    Message = $"Exception during ZarinPal verification: {ex.Message}"
                };
            }
        }
    }
}

