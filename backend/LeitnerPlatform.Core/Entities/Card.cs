using System;

namespace LeitnerPlatform.Core.Entities
{
    public class Card
    {
        public Guid Id { get; set; }
        public Guid CourseId { get; set; }
        public int CardNumber { get; set; }
        public string QuestionText { get; set; } = string.Empty;
        public string AnswerText { get; set; } = string.Empty;
        public string? ImageUrl { get; set; }
        public string? AudioUrl { get; set; }

        public Course? Course { get; set; }
    }
}
