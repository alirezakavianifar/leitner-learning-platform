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

            var subject = $"Leitner Platform - User Registered: {user.Username}";
            var body = $@"
                <h2>New User Registered</h2>
                <table border='1' cellpadding='5' style='border-collapse: collapse; font-family: sans-serif;'>
                    <tr bgcolor='#f2f2f2'><th>Field</th><th>Value</th></tr>
                    <tr><td><b>ID</b></td><td>{user.Id}</td></tr>
                    <tr><td><b>Username</b></td><td>{user.Username}</td></tr>
                    <tr><td><b>Mobile Number</b></td><td>{user.MobileNumber}</td></tr>
                    <tr><td><b>Interests</b></td><td>{user.Interests ?? "None"}</td></tr>
                    <tr><td><b>Educational Field</b></td><td>{user.EducationalField ?? "None"}</td></tr>
                    <tr><td><b>Educational Level</b></td><td>{user.EducationalLevel ?? "None"}</td></tr>
                    <tr><td><b>Created At</b></td><td>{user.CreatedAt:yyyy-MM-dd HH:mm:ss} UTC</td></tr>
                </table>";
            await SendEmailAsync(subject, body);
        }

        public async Task ReplicatePurchaseAsync(Purchase purchase)
        {
            var key = $"purchases/{purchase.Id}.json";
            var json = JsonSerializer.Serialize(purchase, new JsonSerializerOptions { WriteIndented = true });
            await ReplicateAsync(key, json);

            var courseTitle = purchase.Course?.Title ?? purchase.CourseId.ToString();
            var userDetail = purchase.User != null ? $"{purchase.User.Username} ({purchase.User.MobileNumber})" : purchase.UserId.ToString();

            var subject = $"Leitner Platform - Purchase Completed: Course {courseTitle}";
            var body = $@"
                <h2>Purchase Completed</h2>
                <table border='1' cellpadding='5' style='border-collapse: collapse; font-family: sans-serif;'>
                    <tr bgcolor='#f2f2f2'><th>Field</th><th>Value</th></tr>
                    <tr><td><b>Purchase ID</b></td><td>{purchase.Id}</td></tr>
                    <tr><td><b>User</b></td><td>{userDetail}</td></tr>
                    <tr><td><b>Course</b></td><td>{courseTitle}</td></tr>
                    <tr><td><b>Payment Provider</b></td><td>{purchase.PaymentProvider}</td></tr>
                    <tr><td><b>Transaction ID</b></td><td>{purchase.TransactionId}</td></tr>
                    <tr><td><b>Status</b></td><td>{purchase.Status}</td></tr>
                    <tr><td><b>Purchased At</b></td><td>{purchase.PurchasedAt:yyyy-MM-dd HH:mm:ss} UTC</td></tr>
                </table>";
            await SendEmailAsync(subject, body);
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

        private async Task SendEmailAsync(string subject, string body)
        {
            var host = Environment.GetEnvironmentVariable("SMTP_HOST");
            var portStr = Environment.GetEnvironmentVariable("SMTP_PORT");
            var username = Environment.GetEnvironmentVariable("SMTP_USERNAME");
            var password = Environment.GetEnvironmentVariable("SMTP_PASSWORD");
            var receiver = Environment.GetEnvironmentVariable("SMTP_RECEIVER");
            var sender = Environment.GetEnvironmentVariable("SMTP_SENDER") ?? (string.IsNullOrEmpty(username) ? "backup@leitnerplatform.com" : username);

            if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(receiver))
            {
                Console.WriteLine("[Backup Warning] SMTP settings not configured. Email notification skipped.");
                return;
            }

            int port = 587;
            if (!string.IsNullOrEmpty(portStr))
            {
                int.TryParse(portStr, out port);
            }

            try
            {
                using var client = new System.Net.Mail.SmtpClient(host, port)
                {
                    Credentials = new System.Net.NetworkCredential(username, password),
                    EnableSsl = true
                };

                using var mailMessage = new System.Net.Mail.MailMessage
                {
                    From = new System.Net.Mail.MailAddress(sender),
                    Subject = subject,
                    Body = body,
                    IsBodyHtml = true
                };
                mailMessage.To.Add(receiver);

                await client.SendMailAsync(mailMessage);
                Console.WriteLine($"Emailed backup notification to: {receiver}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending backup email: {ex.Message}");
            }
        }
    }
}
