using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Repositories
{
    public class PurchaseRepository : IPurchaseRepository
    {
        private readonly LeitnerDbContext _context;

        public PurchaseRepository(LeitnerDbContext context)
        {
            _context = context;
        }

        public async Task<Purchase?> GetByUserIdAndCourseIdAsync(Guid userId, Guid courseId)
        {
            return await _context.Purchases
                .FirstOrDefaultAsync(p => p.UserId == userId && p.CourseId == courseId);
        }

        public async Task AddAsync(Purchase purchase)
        {
            await _context.Purchases.AddAsync(purchase);
        }

        public async Task UpdateAsync(Purchase purchase)
        {
            _context.Entry(purchase).State = EntityState.Modified;
            await Task.CompletedTask;
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }
    }
}
