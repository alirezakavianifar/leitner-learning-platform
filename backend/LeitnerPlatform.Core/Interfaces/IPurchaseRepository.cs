using System;
using System.Threading.Tasks;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface IPurchaseRepository
    {
        Task<Purchase?> GetByUserIdAndCourseIdAsync(Guid userId, Guid courseId);
        Task AddAsync(Purchase purchase);
        Task UpdateAsync(Purchase purchase);
        Task SaveChangesAsync();
    }
}
