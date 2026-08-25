using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Data
{
    public class LeitnerDbContext : DbContext
    {
        public LeitnerDbContext(DbContextOptions<LeitnerDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users => Set<User>();
        public DbSet<Course> Courses => Set<Course>();
        public DbSet<Card> Cards => Set<Card>();
        public DbSet<LeitnerProgress> LeitnerProgresses => Set<LeitnerProgress>();
        public DbSet<Purchase> Purchases => Set<Purchase>();
        public DbSet<FlashcardReport> FlashcardReports => Set<FlashcardReport>();
        public DbSet<Banner> Banners => Set<Banner>();
        public DbSet<Announcement> Announcements => Set<Announcement>();
        public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
        public DbSet<SystemConfig> SystemConfigs => Set<SystemConfig>();
        public DbSet<CoursePackage> CoursePackages => Set<CoursePackage>();
        public DbSet<CoursePackageItem> CoursePackageItems => Set<CoursePackageItem>();
        public DbSet<PackagePurchase> PackagePurchases => Set<PackagePurchase>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // CoursePackage mapping
            modelBuilder.Entity<CoursePackage>(entity =>
            {
                entity.ToTable("course_packages");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.Title).HasColumnName("title").HasMaxLength(200).IsRequired();
                entity.Property(e => e.Description).HasColumnName("description");
                entity.Property(e => e.Category).HasColumnName("category").HasMaxLength(100);
                entity.Property(e => e.Price).HasColumnName("price").HasPrecision(12, 2).HasDefaultValue(0.00);
                entity.Property(e => e.OriginalPrice).HasColumnName("original_price").HasPrecision(12, 2);
                entity.Property(e => e.ImageUrl).HasColumnName("image_url").HasMaxLength(512);
                entity.Property(e => e.IsPublished).HasColumnName("is_published").HasDefaultValue(true);
                entity.Property(e => e.IsArchived).HasColumnName("is_archived").HasDefaultValue(false);
                entity.Property(e => e.DisplayOrder).HasColumnName("display_order").HasDefaultValue(0);
                entity.Property(e => e.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("CURRENT_TIMESTAMP");
                entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");
            });

            // CoursePackageItem mapping
            modelBuilder.Entity<CoursePackageItem>(entity =>
            {
                entity.ToTable("course_package_items");
                entity.HasKey(e => new { e.PackageId, e.CourseId });
                entity.Property(e => e.PackageId).HasColumnName("package_id").IsRequired();
                entity.Property(e => e.CourseId).HasColumnName("course_id").IsRequired();
                entity.Property(e => e.DisplayOrder).HasColumnName("display_order").HasDefaultValue(0);

                entity.HasOne(e => e.Package)
                    .WithMany(p => p.Items)
                    .HasForeignKey(e => e.PackageId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Course)
                    .WithMany()
                    .HasForeignKey(e => e.CourseId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // PackagePurchase mapping
            modelBuilder.Entity<PackagePurchase>(entity =>
            {
                entity.ToTable("package_purchases");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.UserId).HasColumnName("user_id").IsRequired();
                entity.Property(e => e.PackageId).HasColumnName("package_id").IsRequired();
                entity.Property(e => e.AmountPaid).HasColumnName("amount_paid").HasPrecision(12, 2).HasDefaultValue(0.00);
                entity.Property(e => e.PaymentProvider).HasColumnName("payment_provider").HasMaxLength(50).IsRequired();
                entity.Property(e => e.TransactionId).HasColumnName("transaction_id").HasMaxLength(150).IsRequired();
                entity.Property(e => e.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("PENDING");
                entity.Property(e => e.PurchasedAt).HasColumnName("purchased_at").HasDefaultValueSql("CURRENT_TIMESTAMP");

                entity.HasOne(e => e.User)
                    .WithMany()
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Package)
                    .WithMany()
                    .HasForeignKey(e => e.PackageId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // User mapping
            modelBuilder.Entity<User>(entity =>
            {
                entity.ToTable("users");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.Username).HasColumnName("username").HasMaxLength(100).IsRequired();
                entity.Property(e => e.MobileNumber).HasColumnName("mobile_number").HasMaxLength(15).IsRequired();
                entity.HasIndex(e => e.MobileNumber).IsUnique();
                entity.Property(e => e.Interests).HasColumnName("interests");
                entity.Property(e => e.EducationalField).HasColumnName("educational_field").HasMaxLength(150);
                entity.Property(e => e.EducationalLevel).HasColumnName("educational_level").HasMaxLength(100);
                entity.Property(e => e.IsAdmin).HasColumnName("is_admin").HasDefaultValue(false);
                entity.Property(e => e.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("CURRENT_TIMESTAMP");
            });

            // Course mapping
            modelBuilder.Entity<Course>(entity =>
            {
                entity.ToTable("courses");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.Title).HasColumnName("title").HasMaxLength(200).IsRequired();
                entity.Property(e => e.Description).HasColumnName("description");
                entity.Property(e => e.Category).HasColumnName("category").HasMaxLength(100);
                entity.Property(e => e.Difficulty).HasColumnName("difficulty").HasMaxLength(50);
                entity.Property(e => e.Price).HasColumnName("price").HasPrecision(12, 2).HasDefaultValue(0.00);
                entity.Property(e => e.IsPublished).HasColumnName("is_published").HasDefaultValue(false);
                entity.Property(e => e.Version).HasColumnName("version").HasDefaultValue(1);
                entity.Property(e => e.ChecksumSha256).HasColumnName("checksum_sha256").HasMaxLength(64);
                entity.Property(e => e.DownloadUrl).HasColumnName("download_url").HasMaxLength(512);
                entity.Property(e => e.CardCount).HasColumnName("card_count").HasDefaultValue(0);
                entity.Property(e => e.ImageUrl).HasColumnName("image_url").HasMaxLength(512);
                entity.Property(e => e.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("CURRENT_TIMESTAMP");
                entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");
                entity.Property(e => e.IsArchived).HasColumnName("is_archived").HasDefaultValue(false);
                entity.Property(e => e.ArchivedAt).HasColumnName("archived_at");
                entity.Property(e => e.IsCriticalUpdate).HasColumnName("is_critical_update").HasDefaultValue(false);
            });

            // Card mapping
            modelBuilder.Entity<Card>(entity =>
            {
                entity.ToTable("cards");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.CourseId).HasColumnName("course_id").IsRequired();
                entity.Property(e => e.CardNumber).HasColumnName("card_number").IsRequired();
                entity.Property(e => e.QuestionText).HasColumnName("question_text").IsRequired();
                entity.Property(e => e.AnswerText).HasColumnName("answer_text").IsRequired();
                entity.Property(e => e.ImageUrl).HasColumnName("image_url").HasMaxLength(512);
                entity.Property(e => e.AudioUrl).HasColumnName("audio_url").HasMaxLength(512);

                entity.HasOne(e => e.Course)
                    .WithMany()
                    .HasForeignKey(e => e.CourseId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => new { e.CourseId, e.CardNumber }).IsUnique();
            });

            // LeitnerProgress mapping
            modelBuilder.Entity<LeitnerProgress>(entity =>
            {
                entity.ToTable("leitner_progress");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.UserId).HasColumnName("user_id").IsRequired();
                entity.Property(e => e.CardId).HasColumnName("card_id").IsRequired();
                entity.Property(e => e.CurrentBox).HasColumnName("current_box").HasDefaultValue(1);
                entity.Property(e => e.LastReviewedAt).HasColumnName("last_reviewed_at");
                entity.Property(e => e.NextReviewDue).HasColumnName("next_review_due");

                entity.HasOne(e => e.User)
                    .WithMany()
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Card)
                    .WithMany()
                    .HasForeignKey(e => e.CardId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => new { e.UserId, e.CardId }).IsUnique();
            });

            // Purchase mapping
            modelBuilder.Entity<Purchase>(entity =>
            {
                entity.ToTable("purchases");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.UserId).HasColumnName("user_id").IsRequired();
                entity.Property(e => e.CourseId).HasColumnName("course_id").IsRequired();
                entity.Property(e => e.PaymentProvider).HasColumnName("payment_provider").HasMaxLength(50).IsRequired();
                entity.Property(e => e.TransactionId).HasColumnName("transaction_id").HasMaxLength(150).IsRequired();
                entity.Property(e => e.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("PENDING");
                entity.Property(e => e.PurchasedAt).HasColumnName("purchased_at").HasDefaultValueSql("CURRENT_TIMESTAMP");

                entity.HasOne(e => e.User)
                    .WithMany()
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Course)
                    .WithMany()
                    .HasForeignKey(e => e.CourseId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => new { e.UserId, e.CourseId }).IsUnique();
            });

            // FlashcardReport mapping
            modelBuilder.Entity<FlashcardReport>(entity =>
            {
                entity.ToTable("flashcard_reports");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.UserId).HasColumnName("user_id").IsRequired();
                entity.Property(e => e.UserMobileNumber).HasColumnName("user_mobile_number").HasMaxLength(15).IsRequired();
                entity.Property(e => e.CourseId).HasColumnName("course_id").IsRequired();
                entity.Property(e => e.CardNumber).HasColumnName("card_number").IsRequired();
                entity.Property(e => e.ReportText).HasColumnName("report_text").IsRequired();
                entity.Property(e => e.SubmittedAt).HasColumnName("submitted_at").HasDefaultValueSql("CURRENT_TIMESTAMP");
                entity.Property(e => e.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("PENDING");

                entity.HasOne(e => e.User)
                    .WithMany()
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Course)
                    .WithMany()
                    .HasForeignKey(e => e.CourseId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Banner mapping
            modelBuilder.Entity<Banner>(entity =>
            {
                entity.ToTable("banners");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.ImageUrl).HasColumnName("image_url").HasMaxLength(512).IsRequired();
                entity.Property(e => e.LinkUrl).HasColumnName("link_url").HasMaxLength(512);
                entity.Property(e => e.DisplayOrder).HasColumnName("display_order").HasDefaultValue(0);
                entity.Property(e => e.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            });

            // Announcement mapping
            modelBuilder.Entity<Announcement>(entity =>
            {
                entity.ToTable("announcements");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.Title).HasColumnName("title").HasMaxLength(250).IsRequired();
                entity.Property(e => e.Content).HasColumnName("content").IsRequired();
                entity.Property(e => e.PublishedAt).HasColumnName("published_at").HasDefaultValueSql("CURRENT_TIMESTAMP");
            });

            // AuditLog mapping
            modelBuilder.Entity<AuditLog>(entity =>
            {
                entity.ToTable("audit_logs");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).HasColumnName("id").HasDefaultValueSql("uuid_generate_v4()");
                entity.Property(e => e.ActorUsername).HasColumnName("actor_username").HasMaxLength(100).IsRequired();
                entity.Property(e => e.ActionType).HasColumnName("action_type").HasMaxLength(100).IsRequired();
                entity.Property(e => e.TargetEntity).HasColumnName("target_entity").HasMaxLength(100).IsRequired();
                entity.Property(e => e.BeforeValue).HasColumnName("before_value");
                entity.Property(e => e.AfterValue).HasColumnName("after_value");
                entity.Property(e => e.Timestamp).HasColumnName("timestamp").HasDefaultValueSql("CURRENT_TIMESTAMP");
            });

            // SystemConfig mapping
            modelBuilder.Entity<SystemConfig>(entity =>
            {
                entity.ToTable("system_configs");
                entity.HasKey(e => e.Key);
                entity.Property(e => e.Key).HasColumnName("key").HasMaxLength(100);
                entity.Property(e => e.Value).HasColumnName("value").IsRequired();
                entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("CURRENT_TIMESTAMP");
            });
        }
    }
}
