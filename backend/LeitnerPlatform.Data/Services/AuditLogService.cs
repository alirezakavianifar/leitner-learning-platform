using System;
using System.Threading.Tasks;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Services
{
    public class AuditLogService : IAuditLogService
    {
        private readonly LeitnerDbContext _context;

        public AuditLogService(LeitnerDbContext context)
        {
            _context = context;
        }

        public async Task LogActionAsync(string actorUsername, string actionType, string targetEntity, string? beforeValue, string? afterValue)
        {
            var auditLog = new AuditLog
            {
                Id = Guid.NewGuid(),
                ActorUsername = actorUsername,
                ActionType = actionType,
                TargetEntity = targetEntity,
                BeforeValue = beforeValue,
                AfterValue = afterValue,
                Timestamp = DateTime.UtcNow
            };

            await _context.AuditLogs.AddAsync(auditLog);
            await _context.SaveChangesAsync();
        }
    }
}
