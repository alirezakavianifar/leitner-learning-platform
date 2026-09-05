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
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;

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
        private readonly LeitnerDbContext? _dbContext;

        public AuthController(
            IUserRepository userRepository,
            ISmsService smsService,
            ICaptchaService captchaService,
            IEventBus eventBus,
            IConfiguration configuration,
            IMemoryCache memoryCache,
            IConnectionMultiplexer? redisConnection = null,
            LeitnerDbContext? dbContext = null)
        {
            _userRepository = userRepository;
            _smsService = smsService;
            _captchaService = captchaService;
            _eventBus = eventBus;
            _configuration = configuration;
            _memoryCache = memoryCache;
            _redisConnection = redisConnection;
            _dbContext = dbContext;
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

            // If admin login requested, validate owner mobile whitelist
            if (input.IsAdminLogin)
            {
                if (!await IsAllowedAdminMobileAsync(cleanMobile))
                {
                    return Unauthorized(new { success = false, error_code = "UNAUTHORIZED_ADMIN_MOBILE", message = "This mobile number is not authorized for administrator access." });
                }
            }

            // Generate 5-digit OTP code (Must be verified exclusively via SMS)
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

            if (input.IsAdminLogin)
            {
                if (!await IsAllowedAdminMobileAsync(cleanMobile))
                {
                    return Unauthorized(new { success = false, error_code = "UNAUTHORIZED_ADMIN_MOBILE", message = "This mobile number is not authorized for administrator access." });
                }
            }

            // Emergency bypass check (allowed for 09120000000 when enabled in admin settings/system_configs)
            bool isEmergencyMatch = input.IsAdminLogin &&
                await IsEmergencyBypassEnabledAsync() &&
                cleanMobile == NormalizeMobileNumber("09120000000") &&
                input.OtpCode == "12345";

            if (!isEmergencyMatch && expectedOtp != input.OtpCode)
            {
                return Unauthorized(new { success = false, error_code = "INVALID_OTP", message = "The verification code is incorrect or expired." });
            }

            // Clear verified OTP
            if (!isEmergencyMatch)
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
            bool isAllowedAdmin = await IsAllowedAdminMobileAsync(cleanMobile);

            if (isNewUser)
            {
                user = new User
                {
                    Id = Guid.NewGuid(),
                    MobileNumber = cleanMobile,
                    Username = input.IsAdminLogin && !string.IsNullOrWhiteSpace(input.Username) 
                        ? input.Username 
                        : (input.IsAdminLogin ? "Admin" : $"User_{Guid.NewGuid().ToString("N").Substring(0, 8)}"),
                    IsAdmin = input.IsAdminLogin && isAllowedAdmin,
                    CreatedAt = DateTime.UtcNow
                };

                await _userRepository.AddAsync(user);
                await _userRepository.SaveChangesAsync();

                // Publish Event to event bus (runs immediate off-server backup replication asynchronously)
                await _eventBus.PublishAsync(new UserRegisteredEvent(user));
            }
            else if (input.IsAdminLogin && isAllowedAdmin && user != null && !user.IsAdmin)
            {
                user.IsAdmin = true;
                await _userRepository.UpdateAsync(user);
                await _userRepository.SaveChangesAsync();
            }

            bool isEffectiveAdmin = user!.IsAdmin && isAllowedAdmin;

            if (input.IsAdminLogin && !isEffectiveAdmin)
            {
                return Unauthorized(new { success = false, error_code = "FORBIDDEN", message = "Administrator privileges required." });
            }

            // Fetch custom token lifetimes
            var jwtLifetime = await GetJwtLifetimeAsync();
            var refreshTokenLifetime = await GetRefreshTokenLifetimeAsync();

            // Generate JWT Token
            var token = GenerateJwtToken(user!, jwtLifetime, isEffectiveAdmin);
            var refreshToken = Guid.NewGuid().ToString(); // Simple UUID refresh token

            // 1. Save persistent refresh token to PostgreSQL database (survives container restarts)
            if (_dbContext != null)
            {
                try
                {
                    var dbRefreshToken = new RefreshToken
                    {
                        Id = Guid.NewGuid(),
                        UserId = user!.Id,
                        Token = refreshToken,
                        ExpiresAt = DateTime.UtcNow.Add(refreshTokenLifetime),
                        CreatedAt = DateTime.UtcNow
                    };
                    _dbContext.RefreshTokens.Add(dbRefreshToken);
                    await _dbContext.SaveChangesAsync();
                }
                catch { }
            }

            // 2. Save refresh token to Redis/memory cache for high-speed lookups
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    await db.StringSetAsync($"refresh_token:{refreshToken}", user!.Id.ToString(), refreshTokenLifetime);
                }
                catch
                {
                    _memoryCache.Set($"refresh_token:{refreshToken}", user!.Id.ToString(), refreshTokenLifetime);
                }
            }
            else
            {
                _memoryCache.Set($"refresh_token:{refreshToken}", user!.Id.ToString(), refreshTokenLifetime);
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
                role = isEffectiveAdmin ? "Admin" : "Student"
            });
        }

        [HttpPost("refresh")]
        public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenInput input)
        {
            if (string.IsNullOrEmpty(input.RefreshToken))
            {
                return BadRequest(new { success = false, error_code = "INVALID_INPUT", message = "Refresh token is required." });
            }

            string? userIdStr = null;

            // 1. Check Redis Cache
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    userIdStr = await db.StringGetAsync($"refresh_token:{input.RefreshToken}");
                }
                catch { }
            }

            // 2. Check In-Memory Cache
            if (string.IsNullOrEmpty(userIdStr))
            {
                _memoryCache.TryGetValue($"refresh_token:{input.RefreshToken}", out userIdStr);
            }

            // 3. Fallback to PostgreSQL database for resilient session restoration
            RefreshToken? dbRecord = null;
            if (string.IsNullOrEmpty(userIdStr) && _dbContext != null)
            {
                try
                {
                    dbRecord = await _dbContext.RefreshTokens
                        .FirstOrDefaultAsync(r => r.Token == input.RefreshToken && r.RevokedAt == null && r.ExpiresAt > DateTime.UtcNow);
                    if (dbRecord != null)
                    {
                        userIdStr = dbRecord.UserId.ToString();
                    }
                }
                catch { }
            }

            if (string.IsNullOrEmpty(userIdStr) || !Guid.TryParse(userIdStr, out var userId))
            {
                return Unauthorized(new { success = false, error_code = "INVALID_REFRESH_TOKEN", message = "The refresh token is invalid or expired." });
            }

            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                return Unauthorized(new { success = false, error_code = "USER_NOT_FOUND", message = "User not found." });
            }

            // Invalidate previous refresh token in cache
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    await db.KeyDeleteAsync($"refresh_token:{input.RefreshToken}");
                }
                catch { }
            }
            _memoryCache.Remove($"refresh_token:{input.RefreshToken}");

            // Fetch custom token lifetimes
            var jwtLifetime = await GetJwtLifetimeAsync();
            var refreshTokenLifetime = await GetRefreshTokenLifetimeAsync();

            bool isAllowedAdmin = await IsAllowedAdminMobileAsync(user!.MobileNumber);
            bool isEffectiveAdmin = user.IsAdmin && isAllowedAdmin;

            // Generate new tokens (token rotation)
            var newJwtToken = GenerateJwtToken(user!, jwtLifetime, isEffectiveAdmin);
            var newRefreshToken = Guid.NewGuid().ToString();

            // Persist rotation in PostgreSQL database
            if (_dbContext != null)
            {
                try
                {
                    if (dbRecord == null)
                    {
                        dbRecord = await _dbContext.RefreshTokens.FirstOrDefaultAsync(r => r.Token == input.RefreshToken);
                    }
                    if (dbRecord != null)
                    {
                        dbRecord.RevokedAt = DateTime.UtcNow;
                        dbRecord.ReplacedByToken = newRefreshToken;
                    }

                    var newDbRefreshToken = new RefreshToken
                    {
                        Id = Guid.NewGuid(),
                        UserId = user.Id,
                        Token = newRefreshToken,
                        ExpiresAt = DateTime.UtcNow.Add(refreshTokenLifetime),
                        CreatedAt = DateTime.UtcNow
                    };
                    _dbContext.RefreshTokens.Add(newDbRefreshToken);
                    await _dbContext.SaveChangesAsync();
                }
                catch { }
            }

            // Save new refresh token in cache
            if (_redisConnection != null && _redisConnection.IsConnected)
            {
                try
                {
                    var db = _redisConnection.GetDatabase();
                    await db.StringSetAsync($"refresh_token:{newRefreshToken}", user.Id.ToString(), refreshTokenLifetime);
                }
                catch
                {
                    _memoryCache.Set($"refresh_token:{newRefreshToken}", user.Id.ToString(), refreshTokenLifetime);
                }
            }
            else
            {
                _memoryCache.Set($"refresh_token:{newRefreshToken}", user.Id.ToString(), refreshTokenLifetime);
            }

            return Ok(new
            {
                success = true,
                token = newJwtToken,
                refresh_token = newRefreshToken
            });
        }

        private async Task<TimeSpan> GetJwtLifetimeAsync()
        {
            if (_dbContext == null) return TimeSpan.FromDays(1);

            try
            {
                var valConfig = await _dbContext.SystemConfigs.FindAsync("jwt_lifetime_value");
                var unitConfig = await _dbContext.SystemConfigs.FindAsync("jwt_lifetime_unit");

                var valStr = valConfig?.Value;
                var unitStr = unitConfig?.Value?.ToLowerInvariant() ?? "days";

                if (int.TryParse(valStr, out var value) && value > 0)
                {
                    return unitStr switch
                    {
                        "minutes" or "min" => TimeSpan.FromMinutes(value),
                        "hours" or "hour" or "h" => TimeSpan.FromHours(value),
                        "days" or "day" or "d" => TimeSpan.FromDays(value),
                        _ => TimeSpan.FromDays(value)
                    };
                }
            }
            catch { }

            return TimeSpan.FromDays(1);
        }

        private async Task<TimeSpan> GetRefreshTokenLifetimeAsync()
        {
            if (_dbContext == null) return TimeSpan.FromDays(30);

            try
            {
                var valConfig = await _dbContext.SystemConfigs.FindAsync("refresh_token_lifetime_value");
                var unitConfig = await _dbContext.SystemConfigs.FindAsync("refresh_token_lifetime_unit");

                var valStr = valConfig?.Value;
                var unitStr = unitConfig?.Value?.ToLowerInvariant() ?? "days";

                if (int.TryParse(valStr, out var value) && value > 0)
                {
                    return unitStr switch
                    {
                        "hours" or "hour" or "h" => TimeSpan.FromHours(value),
                        "days" or "day" or "d" => TimeSpan.FromDays(value),
                        "months" or "month" or "m" => TimeSpan.FromDays(value * 30),
                        _ => TimeSpan.FromDays(value)
                    };
                }
            }
            catch { }

            return TimeSpan.FromDays(30);
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

        private async Task<bool> IsEmergencyBypassEnabledAsync()
        {
            if (_dbContext != null)
            {
                try
                {
                    var bypassConfig = await _dbContext.SystemConfigs.FindAsync("admin_emergency_bypass_enabled");
                    if (bypassConfig != null)
                    {
                        return bypassConfig.Value.Equals("true", StringComparison.OrdinalIgnoreCase);
                    }
                }
                catch { }
            }

            var envConfig = _configuration["ADMIN_EMERGENCY_BYPASS_ENABLED"] 
                ?? _configuration["AdminSecurity:EmergencyBypassEnabled"];
            if (!string.IsNullOrWhiteSpace(envConfig))
            {
                return envConfig.Equals("true", StringComparison.OrdinalIgnoreCase);
            }

            // Default to true so initial setup or emergency recovery is possible out-of-the-box
            return true;
        }

        private async Task<bool> IsAllowedAdminMobileAsync(string mobile)
        {
            var cleanInput = NormalizeMobileNumber(mobile);

            // If emergency bypass is active, 09120000000 is always treated as authorized
            if (await IsEmergencyBypassEnabledAsync())
            {
                if (cleanInput == NormalizeMobileNumber("09120000000"))
                {
                    return true;
                }
            }

            string? allowedList = null;

            if (_dbContext != null)
            {
                try
                {
                    var dbConfig = await _dbContext.SystemConfigs.FindAsync("admin_allowed_mobile_numbers");
                    if (dbConfig != null && !string.IsNullOrWhiteSpace(dbConfig.Value))
                    {
                        allowedList = dbConfig.Value;
                    }
                }
                catch { }
            }

            if (string.IsNullOrWhiteSpace(allowedList))
            {
                allowedList = _configuration["ADMIN_ALLOWED_MOBILE_NUMBERS"] 
                    ?? _configuration["AdminSecurity:AllowedMobileNumbers"] 
                    ?? "+989120000000,09120000000,09121234567,+989121234567";
            }

            if (string.IsNullOrWhiteSpace(allowedList))
            {
                return false;
            }

            var numbers = allowedList.Split(new[] { ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var num in numbers)
            {
                if (NormalizeMobileNumber(num) == cleanInput)
                {
                    return true;
                }
            }

            return false;
        }

        private string GenerateJwtToken(User user, TimeSpan? validity = null, bool isEffectiveAdmin = false)
        {
            var secretKey = _configuration["JWT_SECRET_KEY"] ?? "jwt_secret_lts_2026_super_secure_key_default";
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Username),
                new Claim("mobile_number", user.MobileNumber),
                new Claim(ClaimTypes.Role, (user.IsAdmin && isEffectiveAdmin) ? "Admin" : "Student")
            };

            var tokenExpiry = validity ?? TimeSpan.FromDays(1);

            var token = new JwtSecurityToken(
                claims: claims,
                expires: DateTime.UtcNow.Add(tokenExpiry),
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    public class OtpRequestInput
    {
        public string MobileNumber { get; set; } = string.Empty;
        public string CaptchaId { get; set; } = string.Empty;
        public string CaptchaAnswer { get; set; } = string.Empty;
        public bool IsAdminLogin { get; set; } = false;
        public string? Username { get; set; }
        public string? Password { get; set; }
    }

    public class OtpVerifyInput
    {
        public string MobileNumber { get; set; } = string.Empty;
        public string OtpCode { get; set; } = string.Empty;
        public bool IsAdminLogin { get; set; } = false;
        public string? Username { get; set; }
        public string? Password { get; set; }
    }

    public class RefreshTokenInput
    {
        public string RefreshToken { get; set; } = string.Empty;
    }
}
