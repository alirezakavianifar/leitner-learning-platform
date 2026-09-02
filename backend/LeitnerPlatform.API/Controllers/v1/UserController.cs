using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize]
    [ApiController]
    [Route("api/v1/user")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class UserController : ControllerBase
    {
        private readonly IUserRepository _userRepository;

        public UserController(IUserRepository userRepository)
        {
            _userRepository = userRepository;
        }

        [HttpGet("profile")]
        public async Task<IActionResult> GetProfile()
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User profile not found." });
            }

            return Ok(new
            {
                id = user.Id,
                username = user.Username,
                mobile_number = user.MobileNumber,
                interests = user.Interests,
                educational_field = user.EducationalField,
                educational_level = user.EducationalLevel,
                profile_picture_url = user.ProfilePictureUrl,
                created_at = user.CreatedAt
            });
        }

        [HttpPut("profile")]
        public async Task<IActionResult> UpdateProfile([FromBody] ProfileUpdateInput input)
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            if (string.IsNullOrEmpty(input.Username))
            {
                return BadRequest(new { success = false, message = "Username cannot be empty." });
            }

            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User profile not found." });
            }

            // Update allowed fields (ignoring/discarding any changes to mobile number)
            user.Username = input.Username;
            user.Interests = input.Interests;
            user.EducationalField = input.EducationalField;
            user.EducationalLevel = input.EducationalLevel;
            if (input.ProfilePictureUrl != null)
            {
                user.ProfilePictureUrl = input.ProfilePictureUrl;
            }

            await _userRepository.UpdateAsync(user);
            await _userRepository.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Profile updated successfully.",
                profile = new
                {
                    id = user.Id,
                    username = user.Username,
                    mobile_number = user.MobileNumber,
                    interests = user.Interests,
                    educational_field = user.EducationalField,
                    educational_level = user.EducationalLevel,
                    profile_picture_url = user.ProfilePictureUrl,
                    created_at = user.CreatedAt
                }
            });
        }

        [HttpPost("avatar")]
        [RequestSizeLimit(10_000_000)] // 10MB limit
        public async Task<IActionResult> UploadAvatar([FromForm] Microsoft.AspNetCore.Http.IFormFile file)
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            if (file == null || file.Length == 0)
            {
                return BadRequest(new { success = false, message = "No image file uploaded." });
            }

            var allowedExtensions = new[] { ".png", ".jpg", ".jpeg", ".webp" };
            var ext = System.IO.Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!System.Linq.Enumerable.Contains(allowedExtensions, ext))
            {
                return BadRequest(new { success = false, message = "Invalid file type. Allowed formats: PNG, JPG, WEBP." });
            }

            if (file.Length > 5 * 1024 * 1024)
            {
                return BadRequest(new { success = false, message = "File size exceeds the 5MB limit." });
            }

            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User profile not found." });
            }

            try
            {
                var wwwrootPath = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot");
                var avatarsDir = System.IO.Path.Combine(wwwrootPath, "uploads", "avatars");
                if (!System.IO.Directory.Exists(avatarsDir))
                {
                    System.IO.Directory.CreateDirectory(avatarsDir);
                }

                // Delete previous avatar file if exists
                if (!string.IsNullOrEmpty(user.ProfilePictureUrl) && user.ProfilePictureUrl.StartsWith("/uploads/avatars/"))
                {
                    var oldFileName = System.IO.Path.GetFileName(user.ProfilePictureUrl);
                    var oldFilePath = System.IO.Path.Combine(avatarsDir, oldFileName);
                    if (System.IO.File.Exists(oldFilePath))
                    {
                        try { System.IO.File.Delete(oldFilePath); } catch { }
                    }
                }

                var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                var fileName = $"avatar_{user.Id}_{timestamp}{ext}";
                var targetPath = System.IO.Path.Combine(avatarsDir, fileName);

                using (var stream = new System.IO.FileStream(targetPath, System.IO.FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                var relativeUrl = $"/uploads/avatars/{fileName}";
                user.ProfilePictureUrl = relativeUrl;

                await _userRepository.UpdateAsync(user);
                await _userRepository.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    message = "Avatar uploaded successfully.",
                    profile_picture_url = relativeUrl,
                    profile = new
                    {
                        id = user.Id,
                        username = user.Username,
                        mobile_number = user.MobileNumber,
                        interests = user.Interests,
                        educational_field = user.EducationalField,
                        educational_level = user.EducationalLevel,
                        profile_picture_url = user.ProfilePictureUrl,
                        created_at = user.CreatedAt
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Failed to upload avatar: {ex.Message}" });
            }
        }

        [HttpDelete("avatar")]
        public async Task<IActionResult> DeleteAvatar()
        {
            var userId = GetUserId();
            if (userId == Guid.Empty)
            {
                return Unauthorized(new { success = false, message = "User not found or token invalid." });
            }

            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { success = false, message = "User profile not found." });
            }

            if (!string.IsNullOrEmpty(user.ProfilePictureUrl) && user.ProfilePictureUrl.StartsWith("/uploads/avatars/"))
            {
                var wwwrootPath = System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "wwwroot");
                var avatarsDir = System.IO.Path.Combine(wwwrootPath, "uploads", "avatars");
                var oldFileName = System.IO.Path.GetFileName(user.ProfilePictureUrl);
                var oldFilePath = System.IO.Path.Combine(avatarsDir, oldFileName);
                if (System.IO.File.Exists(oldFilePath))
                {
                    try { System.IO.File.Delete(oldFilePath); } catch { }
                }
            }

            user.ProfilePictureUrl = null;
            await _userRepository.UpdateAsync(user);
            await _userRepository.SaveChangesAsync();

            return Ok(new { success = true, message = "Avatar removed successfully." });
        }

        private Guid GetUserId()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                            ?? User.FindFirst("sub")?.Value;

            if (Guid.TryParse(userIdStr, out var id))
            {
                return id;
            }

            return Guid.Empty;
        }
    }

    public class ProfileUpdateInput
    {
        public string Username { get; set; } = string.Empty;
        public string? Interests { get; set; }
        public string? EducationalField { get; set; }
        public string? EducationalLevel { get; set; }
        public string? ProfilePictureUrl { get; set; }
    }
}
