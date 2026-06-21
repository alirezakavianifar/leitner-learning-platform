using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly LeitnerDbContext _context;

        public UserRepository(LeitnerDbContext context)
        {
            _context = context;
        }

        public async Task<User?> GetByIdAsync(Guid id)
        {
            return await _context.Users.FindAsync(id);
        }

        public async Task<User?> GetByMobileNumberAsync(string mobileNumber)
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.MobileNumber == mobileNumber);
        }

        public async Task AddAsync(User user)
        {
            await _context.Users.AddAsync(user);
        }

        public async Task UpdateAsync(User user)
        {
            _context.Entry(user).State = EntityState.Modified;
            await Task.CompletedTask;
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }
    }
}
