using System;
using System.IO;
using DbUp;

namespace LeitnerPlatform.Data
{
    public static class DatabaseMigrator
    {
        public static void Migrate(string connectionString)
        {
            // Find migrations folder
            string? migrationsPath = FindMigrationsPath();
            if (string.IsNullOrEmpty(migrationsPath))
            {
                Console.WriteLine("Warning: Migrations directory not found. Skipping SQL script migrations. EF Core DbContext will still try to ensure DB is created.");
                return;
            }

            Console.WriteLine($"Running migrations from path: {migrationsPath}");

            var upgrader = DeployChanges.To
                .PostgresqlDatabase(connectionString)
                .WithScriptsFromFileSystem(migrationsPath)
                .LogToConsole()
                .Build();

            var result = upgrader.PerformUpgrade();

            if (!result.Successful)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(result.Error);
                Console.ResetColor();
                throw new Exception("Database migration failed.", result.Error);
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Database migrations applied successfully.");
            Console.ResetColor();
        }

        private static string? FindMigrationsPath()
        {
            var baseDir = AppContext.BaseDirectory;
            var pathsToTry = new[]
            {
                Path.Combine(baseDir, "db", "migrations"),
                Path.Combine(baseDir, "deployment", "db", "migrations"),
                Path.Combine(baseDir, "..", "..", "..", "..", "deployment", "db", "migrations"), // For local test/dev inside projects folder
                Path.Combine(Directory.GetCurrentDirectory(), "deployment", "db", "migrations"),
                Path.Combine(Directory.GetCurrentDirectory(), "db", "migrations"),
                Path.Combine(Directory.GetCurrentDirectory(), "..", "deployment", "db", "migrations"),
                // Try from the workspace root directly
                Path.Combine(baseDir, "..", "..", "..", "..", "..", "deployment", "db", "migrations")
            };

            foreach (var path in pathsToTry)
            {
                try
                {
                    var fullPath = Path.GetFullPath(path);
                    if (Directory.Exists(fullPath))
                    {
                        var sqlFiles = Directory.GetFiles(fullPath, "*.sql");
                        if (sqlFiles.Length > 0)
                        {
                            return fullPath;
                        }
                    }
                }
                catch
                {
                    // Ignore exceptions for invalid paths
                }
            }

            return null;
        }
    }
}
