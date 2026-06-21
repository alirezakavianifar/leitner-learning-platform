using System;

namespace LeitnerPlatform.Core.Entities
{
    public class AuditLog
    {
        public Guid Id { get; set; }
        public string ActorUsername { get; set; } = string.Empty;
        public string ActionType { get; set; } = string.Empty;
        public string TargetEntity { get; set; } = string.Empty;
        public string? BeforeValue { get; set; }
        public string? AfterValue { get; set; }
        public DateTime Timestamp { get; set; }
    }
}
