using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Amazon.S3;
using Amazon.S3.Model;
using LeitnerPlatform.Core.Entities;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.Data.Services
{
    public class S3BackupService : IBackupService
    {
        public async Task ReplicateUserAsync(User user)
        {
            var key = $"users/{user.Id}.json";
            var json = JsonSerializer.Serialize(user, new JsonSerializerOptions { WriteIndented = true });
            await ReplicateAsync(key, json);
        }

        public async Task ReplicatePurchaseAsync(Purchase purchase)
        {
            var key = $"purchases/{purchase.Id}.json";
            var json = JsonSerializer.Serialize(purchase, new JsonSerializerOptions { WriteIndented = true });
            await ReplicateAsync(key, json);
        }

        private async Task ReplicateAsync(string objectKey, string content)
        {
            var s3Key = Environment.GetEnvironmentVariable("BACKUP_S3_KEY");
            var s3Secret = Environment.GetEnvironmentVariable("BACKUP_S3_SECRET");
            var s3Endpoint = Environment.GetEnvironmentVariable("BACKUP_S3_ENDPOINT") ?? "https://s3.ir-thr-at1.arvanstorage.ir";
            var s3Bucket = Environment.GetEnvironmentVariable("BACKUP_S3_BUCKET") ?? "leitner-backups";

            if (string.IsNullOrEmpty(s3Key) || string.IsNullOrEmpty(s3Secret))
            {
                // Local fallback
                var localDir = Path.Combine(Directory.GetCurrentDirectory(), "backups");
                Directory.CreateDirectory(localDir);
                var localSubDir = Path.Combine(localDir, Path.GetDirectoryName(objectKey) ?? "");
                Directory.CreateDirectory(localSubDir);

                var localPath = Path.Combine(localDir, objectKey);
                await File.WriteAllTextAsync(localPath, content);
                Console.WriteLine($"[Backup Warning] S3 credentials not configured. Replicated data saved locally to: {localPath}");
                return;
            }

            try
            {
                var config = new AmazonS3Config
                {
                    ServiceURL = s3Endpoint,
                    ForcePathStyle = true
                };

                using var client = new AmazonS3Client(s3Key, s3Secret, config);
                var request = new PutObjectRequest
                {
                    BucketName = s3Bucket,
                    Key = objectKey,
                    ContentBody = content,
                    ContentType = "application/json"
                };

                await client.PutObjectAsync(request);
                Console.WriteLine($"Replicated off-server backup to domestic Object Storage: {s3Bucket}/{objectKey}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error replicating backup to domestic S3 storage: {ex.Message}");
                // Save locally as a secondary safety fallback
                try
                {
                    var localPath = Path.Combine(Directory.GetCurrentDirectory(), "backups", objectKey);
                    var parentDir = Path.GetDirectoryName(localPath);
                    if (!string.IsNullOrEmpty(parentDir))
                    {
                        Directory.CreateDirectory(parentDir);
                    }
                    await File.WriteAllTextAsync(localPath, content);
                    Console.WriteLine($"Secondary safety backup saved locally to: {localPath}");
                }
                catch (Exception localEx)
                {
                    Console.WriteLine($"Critical: Local backup safety failover also failed: {localEx.Message}");
                }
            }
        }
    }
}
