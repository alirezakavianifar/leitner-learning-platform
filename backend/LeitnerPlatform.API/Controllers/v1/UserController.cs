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
                    created_at = user.CreatedAt
                }
            });
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
    }
}
