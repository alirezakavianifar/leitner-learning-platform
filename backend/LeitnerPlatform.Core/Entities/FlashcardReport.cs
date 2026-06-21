using System;

namespace LeitnerPlatform.Core.Entities
{
    public class FlashcardReport
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public Guid CourseId { get; set; }
        public int CardNumber { get; set; }
        public string ReportText { get; set; } = string.Empty;
        public DateTime SubmittedAt { get; set; }
        public string Status { get; set; } = "PENDING";

        public User? User { get; set; }
        public Course? Course { get; set; }
    }
}
