using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.Sqlite;

namespace LeitnerPlatform.Data
{
    /// <summary>
    /// Startup task that verifies, normalizes, and synchronizes ChecksumSha256 for any
    /// course whose package file exists on disk, ensuring packages adhere to the root-level
    /// "course.db" specification and database checksums match physical bytes.
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

                    // Check if package conforms to standard layout (course.db at root)
                    var isCompliant = false;
                    try
                    {
                        using (var zipArchive = ZipFile.OpenRead(zipPath))
                        {
                            var rootDbEntry = zipArchive.GetEntry("course.db");
                            isCompliant = rootDbEntry != null;
                        }
                    }
                    catch
                    {
                        isCompliant = false;
                    }

                    if (!isCompliant)
                    {
                        log($"Normalizing legacy course package for {course.Id} ('{course.Title}')...");
                        await NormalizePackageAsync(zipPath, course.Id, course.Title, course.Description, course.Category, course.Difficulty, course.Price, course.Version);
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

        private static async Task NormalizePackageAsync(
            string zipPath,
            Guid courseId,
            string title,
            string? description,
            string? category,
            string? difficulty,
            decimal price,
            int version)
        {
            var tempExtract = Path.Combine(Path.GetTempPath(), $"norm_src_{Guid.NewGuid()}");
            var buildDir = Path.Combine(Path.GetTempPath(), $"norm_bld_{Guid.NewGuid()}");
            try
            {
                Directory.CreateDirectory(tempExtract);
                ZipFile.ExtractToDirectory(zipPath, tempExtract);

                var dbFiles = Directory.GetFiles(tempExtract, "*.db", SearchOption.AllDirectories);
                if (dbFiles.Length == 0) return;

                var srcDb = dbFiles[0];
                var imagesDir = Path.Combine(buildDir, "images");
                var audioDir = Path.Combine(buildDir, "audio");
                Directory.CreateDirectory(imagesDir);
                Directory.CreateDirectory(audioDir);

                // Flatten all audio/images
                var mediaIndex = Directory.GetFiles(tempExtract, "*.*", SearchOption.AllDirectories)
                    .Where(f => !f.EndsWith(".db", StringComparison.OrdinalIgnoreCase) && !Path.GetFileName(f).Equals("manifest.json", StringComparison.OrdinalIgnoreCase))
                    .GroupBy(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

                var outDb = Path.Combine(buildDir, "course.db");
                using (var destConn = new SqliteConnection($"Data Source={outDb}"))
                {
                    await destConn.OpenAsync();

                    using (var schemaCmd = destConn.CreateCommand())
                    {
                        schemaCmd.CommandText = @"
                            CREATE TABLE IF NOT EXISTS course (
                                id TEXT PRIMARY KEY,
                                title TEXT NOT NULL,
                                description TEXT,
                                category TEXT,
                                difficulty TEXT,
                                price REAL NOT NULL DEFAULT 0.0,
                                version INTEGER NOT NULL DEFAULT 1,
                                created_at TEXT NOT NULL
                            );
                            CREATE TABLE IF NOT EXISTS cards (
                                id TEXT PRIMARY KEY,
                                course_id TEXT NOT NULL,
                                card_number INTEGER NOT NULL,
                                question_text TEXT NOT NULL,
                                answer_text TEXT NOT NULL,
                                image_name TEXT,
                                audio_name TEXT,
                                options TEXT
                            );
                            CREATE UNIQUE INDEX IF NOT EXISTS idx_cards_course_number ON cards (course_id, card_number);
                        ";
                        await schemaCmd.ExecuteNonQueryAsync();
                    }

                    using (var courseCmd = destConn.CreateCommand())
                    {
                        courseCmd.CommandText = "INSERT INTO course (id, title, description, category, difficulty, price, version, created_at) " +
                                                "VALUES ($id,$title,$description,$category,$difficulty,$price,$version,$createdAt)";
                        courseCmd.Parameters.AddWithValue("$id", courseId.ToString());
                        courseCmd.Parameters.AddWithValue("$title", title);
                        courseCmd.Parameters.AddWithValue("$description", (object?)description ?? DBNull.Value);
                        courseCmd.Parameters.AddWithValue("$category", (object?)category ?? DBNull.Value);
                        courseCmd.Parameters.AddWithValue("$difficulty", (object?)difficulty ?? DBNull.Value);
                        courseCmd.Parameters.AddWithValue("$price", price);
                        courseCmd.Parameters.AddWithValue("$version", version);
                        courseCmd.Parameters.AddWithValue("$createdAt", DateTime.UtcNow.ToString("o"));
                        await courseCmd.ExecuteNonQueryAsync();
                    }

                    using (var srcConn = new SqliteConnection($"Data Source={srcDb}"))
                    {
                        await srcConn.OpenAsync();

                        var columns = new System.Collections.Generic.List<string>();
                        using (var schemaCmd = new SqliteCommand("PRAGMA table_info(cards)", srcConn))
                        using (var reader = await schemaCmd.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                columns.Add(reader.GetString(1).ToLowerInvariant());
                            }
                        }

                        int idxCardNum = columns.IndexOf("card_number");
                        if (idxCardNum == -1) idxCardNum = columns.IndexOf("number");
                        if (idxCardNum == -1) idxCardNum = columns.IndexOf("id");

                        int idxQuestion = columns.IndexOf("question_text");
                        if (idxQuestion == -1) idxQuestion = columns.IndexOf("questions");
                        if (idxQuestion == -1) idxQuestion = columns.IndexOf("question");
                        if (idxQuestion == -1) idxQuestion = columns.IndexOf("front");

                        int idxAnswer = columns.IndexOf("answer_text");
                        if (idxAnswer == -1) idxAnswer = columns.IndexOf("answer");
                        if (idxAnswer == -1) idxAnswer = columns.IndexOf("answers");
                        if (idxAnswer == -1) idxAnswer = columns.IndexOf("back");

                        int idxImage = columns.IndexOf("image_name");
                        if (idxImage == -1) idxImage = columns.IndexOf("front image");
                        if (idxImage == -1) idxImage = columns.IndexOf("image");
                        if (idxImage == -1) idxImage = columns.IndexOf("image_url");

                        int idxAudio = columns.IndexOf("audio_name");
                        if (idxAudio == -1) idxAudio = columns.IndexOf("front voice");
                        if (idxAudio == -1) idxAudio = columns.IndexOf("audio");
                        if (idxAudio == -1) idxAudio = columns.IndexOf("audio_url");

                        using (var tx = destConn.BeginTransaction())
                        using (var cmd = new SqliteCommand("SELECT * FROM cards", srcConn))
                        using (var reader = await cmd.ExecuteReaderAsync())
                        {
                            int rowCounter = 1;
                            while (await reader.ReadAsync())
                            {
                                int cardNum = idxCardNum != -1 && !reader.IsDBNull(idxCardNum) ? Convert.ToInt32(reader.GetValue(idxCardNum)) : rowCounter;
                                string qText = idxQuestion != -1 && !reader.IsDBNull(idxQuestion) ? reader.GetString(idxQuestion) : "Question";
                                string aText = idxAnswer != -1 && !reader.IsDBNull(idxAnswer) ? reader.GetString(idxAnswer) : "Answer";
                                string? img = idxImage != -1 && !reader.IsDBNull(idxImage) ? reader.GetString(idxImage) : null;
                                string? aud = idxAudio != -1 && !reader.IsDBNull(idxAudio) ? reader.GetString(idxAudio) : null;

                                var imgFileName = !string.IsNullOrEmpty(img) ? Path.GetFileName(img) : null;
                                var audFileName = !string.IsNullOrEmpty(aud) ? Path.GetFileName(aud) : null;

                                if (imgFileName != null && mediaIndex.TryGetValue(imgFileName, out var imgSrc))
                                {
                                    var dest = Path.Combine(imagesDir, imgFileName);
                                    if (!File.Exists(dest)) File.Copy(imgSrc, dest);
                                }
                                if (audFileName != null && mediaIndex.TryGetValue(audFileName, out var audSrc))
                                {
                                    var dest = Path.Combine(audioDir, audFileName);
                                    if (!File.Exists(dest)) File.Copy(audSrc, dest);
                                }

                                using var insCmd = destConn.CreateCommand();
                                insCmd.Transaction = tx;
                                insCmd.CommandText = "INSERT INTO cards (id, course_id, card_number, question_text, answer_text, image_name, audio_name) " +
                                                     "VALUES ($id,$courseId,$cardNum,$question,$answer,$img,$aud)";
                                insCmd.Parameters.AddWithValue("$id", Guid.NewGuid().ToString());
                                insCmd.Parameters.AddWithValue("$courseId", courseId.ToString());
                                insCmd.Parameters.AddWithValue("$cardNum", cardNum);
                                insCmd.Parameters.AddWithValue("$question", qText);
                                insCmd.Parameters.AddWithValue("$answer", aText);
                                insCmd.Parameters.AddWithValue("$img", (object?)imgFileName ?? DBNull.Value);
                                insCmd.Parameters.AddWithValue("$aud", (object?)audFileName ?? DBNull.Value);
                                await insCmd.ExecuteNonQueryAsync();

                                rowCounter++;
                            }
                            await tx.CommitAsync();
                        }
                    }
                }

                SqliteConnection.ClearAllPools();
                if (Directory.GetFiles(imagesDir).Length == 0) Directory.Delete(imagesDir, true);
                if (Directory.GetFiles(audioDir).Length == 0) Directory.Delete(audioDir, true);

                var tempNewZip = Path.Combine(Path.GetTempPath(), $"norm_out_{Guid.NewGuid()}.zip");
                ZipFile.CreateFromDirectory(buildDir, tempNewZip, CompressionLevel.Optimal, false);

                File.Delete(zipPath);
                File.Copy(tempNewZip, zipPath);
                File.Delete(tempNewZip);
            }
            finally
            {
                try { if (Directory.Exists(tempExtract)) Directory.Delete(tempExtract, true); } catch { }
                try { if (Directory.Exists(buildDir)) Directory.Delete(buildDir, true); } catch { }
            }
        }
    }
}
