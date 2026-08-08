using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace LeitnerPlatform.Data
{
    /// <summary>
    /// One-time, self-limiting startup task that computes and persists
    /// ChecksumSha256 for any course whose package file already exists on
    /// disk but predates the checksum-computation feature (e.g. courses
    /// uploaded before that logic was deployed). Safe to run on every
    /// startup: once a course has a checksum, it is skipped on subsequent
    /// runs.
    /// </summary>
    public static class ChecksumBackfiller
    {
        public static async Task BackfillMissingChecksumsAsync(
            LeitnerDbContext context,
            string wwwrootPath,
            Action<string> log)
        {
            var coursesMissingChecksum = await context.Courses
                .Where(c => (c.ChecksumSha256 == null || c.ChecksumSha256 == "") && c.DownloadUrl != null)
                .ToListAsync();

            if (coursesMissingChecksum.Count == 0)
            {
                return;
            }

            var updated = 0;
            foreach (var course in coursesMissingChecksum)
            {
                try
                {
                    var relativePath = course.DownloadUrl!.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                    var zipPath = Path.Combine(wwwrootPath, relativePath);
                    if (!File.Exists(zipPath))
                    {
                        log($"Checksum backfill skipped for course {course.Id} ('{course.Title}'): package file not found at {zipPath}.");
                        continue;
                    }

                    using var sha256 = SHA256.Create();
                    using var stream = File.OpenRead(zipPath);
                    var hashBytes = await sha256.ComputeHashAsync(stream);
                    course.ChecksumSha256 = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();
                    updated++;
                }
                catch (Exception ex)
                {
                    log($"Checksum backfill failed for course {course.Id} ('{course.Title}'): {ex.Message}");
                }
            }

            if (updated > 0)
            {
                await context.SaveChangesAsync();
                log($"Checksum backfill complete: updated {updated} course(s).");
            }
        }
    }
}
