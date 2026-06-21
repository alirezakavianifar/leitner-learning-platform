using System;

namespace LeitnerPlatform.Core.Entities
{
    public class Course
    {
        public Guid Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? Category { get; set; }
        public string? Difficulty { get; set; }
        public decimal Price { get; set; }
        public bool IsPublished { get; set; }
        public int Version { get; set; } = 1;
        public string? ChecksumSha256 { get; set; }
        public string? DownloadUrl { get; set; }
        public int CardCount { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
