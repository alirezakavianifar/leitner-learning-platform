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
        public string? ImageUrl { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        // Soft-delete: archived courses are hidden from the public catalog and the
        // admin "active" list, but their row, cards, and purchases stay intact so
        // users who already bought/downloaded them keep access.
        public bool IsArchived { get; set; }
        public DateTime? ArchivedAt { get; set; }

        // Set by an admin when re-uploading a package that fixes a known issue,
        // so clients can prompt more assertively than a routine content update.
        public bool IsCriticalUpdate { get; set; }

        // Comma-separated list of target distribution platforms/flavors
        // (zarinpal, bazaar, myket, googleplay, ios)
        public string AllowedPlatforms { get; set; } = "zarinpal,bazaar,myket,googleplay,ios";
    }
}
