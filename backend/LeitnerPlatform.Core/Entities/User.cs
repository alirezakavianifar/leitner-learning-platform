using System;

namespace LeitnerPlatform.Core.Entities
{
    public class User
    {
        public Guid Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string MobileNumber { get; set; } = string.Empty;
        public string? Interests { get; set; }
        public string? EducationalField { get; set; }
        public string? EducationalLevel { get; set; }
        public string? ProfilePictureUrl { get; set; }
        public bool IsAdmin { get; set; } = false;
        public DateTime CreatedAt { get; set; }
    }
}
