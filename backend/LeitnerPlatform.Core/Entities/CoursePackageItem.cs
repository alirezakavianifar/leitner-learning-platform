using System;

namespace LeitnerPlatform.Core.Entities
{
    public class CoursePackageItem
    {
        public Guid PackageId { get; set; }
        public Guid CourseId { get; set; }
        public int DisplayOrder { get; set; } = 0;

        public CoursePackage? Package { get; set; }
        public Course? Course { get; set; }
    }
}
