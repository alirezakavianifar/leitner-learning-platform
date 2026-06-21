using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Repositories
{
    public class CourseRepository : ICourseRepository
    {
        private readonly LeitnerDbContext _context;

        public CourseRepository(LeitnerDbContext context)
        {
            _context = context;
        }

        public async Task<Course?> GetByIdAsync(Guid id)
        {
            return await _context.Courses.FindAsync(id);
        }

        public async Task<List<Course>> GetAllPublishedAsync()
        {
            return await _context.Courses
                .Where(c => c.IsPublished)
                .OrderBy(c => c.Title)
                .ToListAsync();
        }

        public async Task<List<Card>> GetCardsByCourseIdAsync(Guid courseId)
        {
            return await _context.Cards
                .Where(c => c.CourseId == courseId)
                .OrderBy(c => c.CardNumber)
                .ToListAsync();
        }
    }
}
