using System.Threading.Tasks;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface IAuditLogService
    {
        Task LogActionAsync(string actorUsername, string actionType, string targetEntity, string? beforeValue, string? afterValue);
    }
}
