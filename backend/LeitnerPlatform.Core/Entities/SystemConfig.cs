using System;

namespace LeitnerPlatform.Core.Entities
{
    public class SystemConfig
    {
        public string Key { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
