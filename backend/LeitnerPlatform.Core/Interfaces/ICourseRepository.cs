using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface ICourseRepository
    {
        Task<Course?> GetByIdAsync(Guid id);
        Task<List<Course>> GetAllPublishedAsync();
        Task<List<Card>> GetCardsByCourseIdAsync(Guid courseId);
    }
}
