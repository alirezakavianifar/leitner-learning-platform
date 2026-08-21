using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace LeitnerPlatform.Data
{
    /// <summary>
    /// Startup task that computes and synchronizes ChecksumSha256 for any
    /// course whose package file exists on disk, ensuring database records
    /// always match the exact physical archive files.
    /// </summary>
    public static class ChecksumBackfiller
    {
        public static async Task BackfillMissingChecksumsAsync(
            LeitnerDbContext context,
            string wwwrootPath,
            Action<string> log)
        {
            var courses = await context.Courses
                .Where(c => c.DownloadUrl != null && c.DownloadUrl != "")
                .ToListAsync();

            if (courses.Count == 0)
            {
                return;
            }

            var updated = 0;
            foreach (var course in courses)
            {
                try
                {
                    var relativePath = course.DownloadUrl!.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                    var zipPath = Path.Combine(wwwrootPath, relativePath);
                    if (!File.Exists(zipPath))
                    {
                        continue;
                    }

                    using var sha256 = SHA256.Create();
                    using var stream = File.OpenRead(zipPath);
                    var hashBytes = await sha256.ComputeHashAsync(stream);
                    var actualChecksum = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();

                    if (!string.Equals(course.ChecksumSha256, actualChecksum, StringComparison.OrdinalIgnoreCase))
                    {
                        course.ChecksumSha256 = actualChecksum;
                        updated++;
                        log($"Synchronized checksum for course {course.Id} ('{course.Title}') to {actualChecksum}.");
                    }
                }
                catch (Exception ex)
                {
                    log($"Checksum sync failed for course {course.Id} ('{course.Title}'): {ex.Message}");
                }
            }

            if (updated > 0)
            {
                await context.SaveChangesAsync();
                log($"Checksum sync complete: updated {updated} course(s).");
            }
        }
    }
}
