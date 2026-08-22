using System;
using System.Collections.Generic;

namespace LeitnerPlatform.Core.Entities
{
    public class CoursePackage
    {
        public Guid Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? Category { get; set; }
        public decimal Price { get; set; }
        public decimal? OriginalPrice { get; set; }
        public bool IsPublished { get; set; } = true;
        public bool IsArchived { get; set; } = false;
        public int DisplayOrder { get; set; } = 0;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        public ICollection<CoursePackageItem> Items { get; set; } = new List<CoursePackageItem>();
    }
}
