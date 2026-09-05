using System;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;
using StackExchange.Redis;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Services
{
    public class CaptchaService : ICaptchaService
    {
        private readonly IMemoryCache _memoryCache;
        private readonly IConnectionMultiplexer? _redisConnection;
        private readonly Random _random = new Random();

        public CaptchaService(IMemoryCache memoryCache, IConnectionMultiplexer? redisConnection = null)
        {
            _memoryCache = memoryCache;
            _redisConnection = redisConnection;
        }

        public async Task<(string Id, string ImageBase64)> GenerateCaptchaAsync()
        {
            int num1 = _random.Next(5, 20);
            int num2 = _random.Next(1, 10);
            bool isAddition = _random.Next(0, 2) == 0;

            int answer = isAddition ? (num1 + num2) : (num1 - num2);
            string opSymbol = isAddition ? "+" : "-";
            string questionText = $"{num1} {opSymbol} {num2} = ?";

            string captchaId = Guid.NewGuid().ToString();

            // Save to cache with 2 minutes expiry
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    await db.StringSetAsync($"captcha:{captchaId}", answer.ToString(), TimeSpan.FromMinutes(2));
                }
                catch
                {
                    SaveToMemoryCache(captchaId, answer);
                }
            }
            else
            {
                SaveToMemoryCache(captchaId, answer);
            }

            // Create SVG image representation
            string svg = $@"<svg xmlns=""http://www.w3.org/2000/svg"" width=""150"" height=""50"" viewBox=""0 0 150 50"">
              <rect width=""100%"" height=""100%"" fill=""#f0f0f0"" rx=""5"" ry=""5"" />
              <line x1=""10"" y1=""15"" x2=""140"" y2=""35"" stroke=""#ccc"" stroke-width=""2"" />
              <line x1=""15"" y1=""40"" x2=""135"" y2=""12"" stroke=""#ccc"" stroke-width=""2"" />
              <text x=""75"" y=""32"" text-anchor=""middle"" font-family=""monospace, Arial"" font-size=""22"" fill=""#d32f2f"" font-weight=""bold"" letter-spacing=""2"">{questionText}</text>
            </svg>";

            var base64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(svg));
            return (captchaId, base64);
        }

        public async Task<bool> ValidateCaptchaAsync(string id, string answer)
        {
            if (string.IsNullOrEmpty(id) || string.IsNullOrEmpty(answer))
            {
                return false;
            }

            string? expectedAnswer = null;

            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    expectedAnswer = await db.StringGetAsync($"captcha:{id}");
                    if (expectedAnswer != null)
                    {
                        await db.KeyDeleteAsync($"captcha:{id}");
                    }
                }
                catch
                {
                    expectedAnswer = GetFromMemoryCache(id);
                }
            }
            else
            {
                expectedAnswer = GetFromMemoryCache(id);
            }

            var cleanAnswer = NormalizeDigits(answer.Trim());
            return expectedAnswer == cleanAnswer;
        }

        private static string NormalizeDigits(string input)
        {
            if (string.IsNullOrEmpty(input)) return string.Empty;
            return input
                .Replace('۰', '0').Replace('۱', '1').Replace('۲', '2').Replace('۳', '3').Replace('۴', '4')
                .Replace('۵', '5').Replace('۶', '6').Replace('۷', '7').Replace('۸', '8').Replace('۹', '9')
                .Replace('٠', '0').Replace('١', '1').Replace('٢', '2').Replace('٣', '3').Replace('٤', '4')
                .Replace('٥', '5').Replace('٦', '6').Replace('٧', '7').Replace('٨', '8').Replace('٩', '9');
        }

        private void SaveToMemoryCache(string captchaId, int answer)
        {
            _memoryCache.Set($"captcha:{captchaId}", answer.ToString(), TimeSpan.FromMinutes(2));
        }

        private string? GetFromMemoryCache(string captchaId)
        {
            if (_memoryCache.TryGetValue($"captcha:{captchaId}", out string? val))
            {
                _memoryCache.Remove($"captcha:{captchaId}");
                return val;
            }
            return null;
        }
    }
}
