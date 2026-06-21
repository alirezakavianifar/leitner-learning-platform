using System;
using System.Threading.Tasks;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface IUserRepository
    {
        Task<User?> GetByIdAsync(Guid id);
        Task<User?> GetByMobileNumberAsync(string mobileNumber);
        Task AddAsync(User user);
        Task UpdateAsync(User user);
        Task SaveChangesAsync();
    }
}
