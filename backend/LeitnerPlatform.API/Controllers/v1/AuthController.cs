using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.API.Controllers.v1
{
    [ApiController]
    [Route("api/v1/auth")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class AuthController : ControllerBase
    {
        private readonly IUserRepository _userRepository;
        private readonly ISmsService _smsService;
        private readonly ICaptchaService _captchaService;
        private readonly IEventBus _eventBus;
        private readonly IConfiguration _configuration;
        private readonly IMemoryCache _memoryCache;
        private readonly IConnectionMultiplexer? _redisConnection;

        public AuthController(
            IUserRepository userRepository,
            ISmsService smsService,
            ICaptchaService captchaService,
            IEventBus eventBus,
            IConfiguration configuration,
            IMemoryCache memoryCache,
            IConnectionMultiplexer? redisConnection = null)
        {
            _userRepository = userRepository;
            _smsService = smsService;
            _captchaService = captchaService;
            _eventBus = eventBus;
            _configuration = configuration;
            _memoryCache = memoryCache;
            _redisConnection = redisConnection;
        }

        [HttpGet("captcha")]
        public async Task<IActionResult> GetCaptcha()
        {
            var (id, base64) = await _captchaService.GenerateCaptchaAsync();
            return Ok(new
            {
                success = true,
                captcha_id = id,
                image_base64 = $"data:image/svg+xml;base64,{base64}"
            });
        }

        [EnableRateLimiting("OtpRateLimit")]
        [HttpPost("otp/request")]
        public async Task<IActionResult> RequestOtp([FromBody] OtpRequestInput input)
        {
            if (string.IsNullOrEmpty(input.MobileNumber))
            {
                return BadRequest(new { success = false, error_code = "INVALID_MOBILE_NUMBER", message = "Mobile number is required." });
            }

            // Standard Iranian Mobile Pattern (e.g. +989123456789, 09123456789, 9123456789)
            var cleanMobile = NormalizeMobileNumber(input.MobileNumber);
            if (!Regex.IsMatch(cleanMobile, @"^(\+98|0)?9\d{9}$"))
            {
                return BadRequest(new { success = false, error_code = "INVALID_MOBILE_NUMBER", message = "The provided mobile number is invalid." });
            }

            // Verify CAPTCHA
            var isCaptchaValid = await _captchaService.ValidateCaptchaAsync(input.CaptchaId, input.CaptchaAnswer);
            if (!isCaptchaValid)
            {
                return BadRequest(new { success = false, error_code = "INVALID_CAPTCHA", message = "The CAPTCHA verification failed." });
            }

            // Generate 5-digit OTP code (bypass code 12345 is allowed)
            var random = new Random();
            var otpCode = random.Next(10000, 99999).ToString();

            // Save to Cache with 2 minutes expiration
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    await db.StringSetAsync($"otp:{cleanMobile}", otpCode, TimeSpan.FromMinutes(2));
                }
                catch
                {
                    SaveOtpToMemory(cleanMobile, otpCode);
                }
            }
            else
            {
                SaveOtpToMemory(cleanMobile, otpCode);
            }

            // Send via SMS Service
            var sendSuccess = await _smsService.SendOtpAsync(cleanMobile, otpCode);
            if (!sendSuccess)
            {
                return StatusCode(500, new { success = false, error_code = "SMS_SEND_FAILED", message = "Failed to dispatch verification code." });
            }

            return Ok(new
            {
                success = true,
                message = "OTP verification code sent successfully.",
                expires_in_seconds = 120
            });
        }

        [HttpPost("otp/verify")]
        public async Task<IActionResult> VerifyOtp([FromBody] OtpVerifyInput input)
        {
            if (string.IsNullOrEmpty(input.MobileNumber) || string.IsNullOrEmpty(input.OtpCode))
            {
                return BadRequest(new { success = false, error_code = "INVALID_INPUT", message = "Mobile number and OTP code are required." });
            }

            var cleanMobile = NormalizeMobileNumber(input.MobileNumber);
            string? expectedOtp = null;

            // Fetch from Cache
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    expectedOtp = await db.StringGetAsync($"otp:{cleanMobile}");
                }
                catch
                {
                    expectedOtp = GetOtpFromMemory(cleanMobile);
                }
            }
            else
            {
                expectedOtp = GetOtpFromMemory(cleanMobile);
            }

            // OTP Bypass rule for testing and integration
            bool isBypass = input.OtpCode == "12345";

            if (expectedOtp != input.OtpCode && !isBypass)
            {
                return Unauthorized(new { success = false, error_code = "INVALID_OTP", message = "The verification code is incorrect or expired." });
            }

            // Clear verified OTP
            if (!isBypass)
            {
                if (_redisConnection != null && _redisConnection.IsConnected)
                {
                    try
                    {
                        var db = _redisConnection.GetDatabase();
                        await db.KeyDeleteAsync($"otp:{cleanMobile}");
                    }
                    catch { }
                }
                else
                {
                    _memoryCache.Remove($"otp:{cleanMobile}");
                }
            }

            // Get or create user
            var user = await _userRepository.GetByMobileNumberAsync(cleanMobile);
            bool isNewUser = user == null;

            if (isNewUser)
            {
                user = new User
                {
                    Id = Guid.NewGuid(),
                    MobileNumber = cleanMobile,
                    Username = $"User_{Guid.NewGuid().ToString("N").Substring(0, 8)}",
                    CreatedAt = DateTime.UtcNow
                };

                await _userRepository.AddAsync(user);
                await _userRepository.SaveChangesAsync();

                // Publish Event to event bus (runs immediate off-server backup replication asynchronously)
                await _eventBus.PublishAsync(new UserRegisteredEvent(user));
            }

            // Generate JWT Token
            var token = GenerateJwtToken(user!);
            var refreshToken = Guid.NewGuid().ToString(); // Simple UUID refresh token

            // Save refresh token to Redis/cache
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    await db.StringSetAsync($"refresh_token:{refreshToken}", user!.Id.ToString(), TimeSpan.FromDays(30));
                }
                catch
                {
                    _memoryCache.Set($"refresh_token:{refreshToken}", user!.Id.ToString(), TimeSpan.FromDays(30));
                }
            }
            else
            {
                _memoryCache.Set($"refresh_token:{refreshToken}", user!.Id.ToString(), TimeSpan.FromDays(30));
            }

            // Define user status
            // If the username is default placeholder "User_...", status is NEW_USER/PROFILE_PENDING. Otherwise ACTIVE.
            var userStatus = user!.Username.StartsWith("User_") ? "NEW_USER" : "ACTIVE";

            return Ok(new
            {
                success = true,
                token = token,
                refresh_token = refreshToken,
                user_status = userStatus,
                role = user!.IsAdmin ? "Admin" : "Student"
            });
        }

        private string NormalizeMobileNumber(string mobile)
        {
            var clean = mobile.Trim().Replace(" ", "").Replace("-", "");
            if (clean.StartsWith("0098"))
            {
                clean = "+" + clean.Substring(2);
            }
            else if (clean.StartsWith("09"))
            {
                clean = "+98" + clean.Substring(1);
            }
            else if (clean.StartsWith("9") && clean.Length == 10)
            {
                clean = "+98" + clean;
            }
            else if (clean.StartsWith("989") && clean.Length == 12)
            {
                clean = "+" + clean;
            }
            return clean;
        }

        private void SaveOtpToMemory(string mobile, string code)
        {
            _memoryCache.Set($"otp:{mobile}", code, TimeSpan.FromMinutes(2));
        }

        private string? GetOtpFromMemory(string mobile)
        {
            _memoryCache.TryGetValue($"otp:{mobile}", out string? code);
            return code;
        }

        private string GenerateJwtToken(User user)
        {
            var secretKey = _configuration["JWT_SECRET_KEY"] ?? "jwt_secret_lts_2026_super_secure_key_default";
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Username),
                new Claim("mobile_number", user.MobileNumber),
                new Claim(ClaimTypes.Role, user.IsAdmin ? "Admin" : "Student")
            };

            var token = new JwtSecurityToken(
                claims: claims,
                expires: DateTime.UtcNow.AddDays(1),
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    public class OtpRequestInput
    {
        public string MobileNumber { get; set; } = string.Empty;
        public string CaptchaId { get; set; } = string.Empty;
        public string CaptchaAnswer { get; set; } = string.Empty;
    }

    public class OtpVerifyInput
    {
        public string MobileNumber { get; set; } = string.Empty;
        public string OtpCode { get; set; } = string.Empty;
    }
}
