using System.Threading.Tasks;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface IBackupService
    {
        Task ReplicateUserAsync(User user);
        Task ReplicatePurchaseAsync(Purchase purchase);
    }
}
