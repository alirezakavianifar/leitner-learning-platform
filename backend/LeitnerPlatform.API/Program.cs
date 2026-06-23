using System;
using System.Text;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using LeitnerPlatform.API.Services;
using LeitnerPlatform.Core.Events;
using LeitnerPlatform.Core.Interfaces;
using LeitnerPlatform.Data;
using LeitnerPlatform.Data.Repositories;
using LeitnerPlatform.Data.Services;

var builder = WebApplication.CreateBuilder(args);

// 1. Add Configuration
var connectionString = builder.Configuration["ConnectionStrings__DefaultConnection"] 
                       ?? builder.Configuration.GetConnectionString("DefaultConnection") 
                       ?? "Server=localhost;Port=5432;Database=leitner_db;User Id=leitner_admin;Password=leitner_secure_pass_2026;";

// 2. Add controllers
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.SnakeCaseLower;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// 3. Add Memory Cache
builder.Services.AddMemoryCache();

// 4. Add Redis Connection Multiplexer (Singleton)
var redisConn = builder.Configuration["Redis__ConnectionString"] 
                ?? builder.Configuration.GetConnectionString("Redis");

if (!string.IsNullOrEmpty(redisConn))
{
    try
    {
        var connectionMultiplexer = ConnectionMultiplexer.Connect(redisConn);
        builder.Services.AddSingleton<IConnectionMultiplexer>(connectionMultiplexer);
        Console.WriteLine("Redis Connection multiplexer registered successfully.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: Failed to connect to Redis. Caching will use in-memory. Error: {ex.Message}");
    }
}

// 5. Add Database Context
builder.Services.AddDbContext<LeitnerDbContext>(options =>
    options.UseNpgsql(connectionString));

// 6. Register Repository Abstractions
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<ICourseRepository, CourseRepository>();
builder.Services.AddScoped<IPurchaseRepository, PurchaseRepository>();

// 7. Register Infrastructure Services
builder.Services.AddHttpClient<ISmsService, SmsService>();
builder.Services.AddScoped<ICaptchaService, CaptchaService>();
builder.Services.AddScoped<IBackupService, S3BackupService>();
builder.Services.AddScoped<IAuditLogService, AuditLogService>();

// 8. Register Channel Event Bus (Singleton & Hosted Processor)
builder.Services.AddSingleton<IEventBus, ChannelEventBus>();
builder.Services.AddHostedService<EventBusProcessor>();

// 9. Configure JWT Authentication
var jwtSecretKey = builder.Configuration["JWT_SECRET_KEY"] ?? "jwt_secret_lts_2026_super_secure_key_default";
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false; // Set to true in prod HTTPS environment
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecretKey)),
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };
});

// 10. Configure Native Rate Limiting Middleware
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    
    // A. OTP rate limiting (5 per hour)
    options.AddPolicy("OtpRateLimit", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 5, // 5 requests
                QueueLimit = 0,
                Window = TimeSpan.FromHours(1) // per 1 hour
            }));

    // B. General rate limiting (100 per minute per IP)
    options.AddPolicy("GeneralRateLimit", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 100,
                QueueLimit = 0,
                Window = TimeSpan.FromMinutes(1)
            }));

    // C. Admin rate limiting (60 per minute per authenticated user or IP)
    options.AddPolicy("AdminRateLimit", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                          ?? httpContext.User.FindFirst("sub")?.Value 
                          ?? httpContext.Connection.RemoteIpAddress?.ToString() 
                          ?? "anonymous",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 60,
                QueueLimit = 0,
                Window = TimeSpan.FromMinutes(1)
            }));
});

// 11. CORS setup
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// 12. Run Database Upgrader/Migrator
try
{
    Console.WriteLine("Executing DatabaseMigrator migrations...");
    DatabaseMigrator.Migrate(connectionString);
}
catch (Exception ex)
{
    Console.WriteLine($"Critical Warning: Database migration failed at startup. EF Core will create schema if database is blank. Error: {ex.Message}");
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<LeitnerDbContext>();
    dbContext.Database.EnsureCreated();
}

// 13. Map Event Bus Subscriptions
var eventBus = app.Services.GetRequiredService<IEventBus>();

eventBus.Subscribe<UserRegisteredEvent>(async @event =>
{
    Console.WriteLine($"Event Bus received UserRegisteredEvent for {@event.User.MobileNumber}. Triggering S3 Backup...");
    using var scope = app.Services.CreateScope();
    var backupService = scope.ServiceProvider.GetRequiredService<IBackupService>();
    await backupService.ReplicateUserAsync(@event.User);
});

eventBus.Subscribe<PurchaseCompletedEvent>(async @event =>
{
    Console.WriteLine($"Event Bus received PurchaseCompletedEvent for user {@event.Purchase.UserId}, Course {@event.Purchase.CourseId}. Triggering S3 Backup...");
    using var scope = app.Services.CreateScope();
    var backupService = scope.ServiceProvider.GetRequiredService<IBackupService>();
    await backupService.ReplicatePurchaseAsync(@event.Purchase);
});

// 14. Configure request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

// Inject Production Security Response Headers
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("Referrer-Policy", "no-referrer");
    context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
    context.Response.Headers.Append("Content-Security-Policy", "default-src 'self'; frame-ancestors 'none';");
    await next();
});

app.UseCors("AllowAll");

app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.UseRateLimiter();

app.MapControllers();

// Add fallback route
app.MapGet("/", () => "Leitner Learning Platform REST API v1 is active.");

app.Run();

// Needed for WebApplicationFactory integration testing
public partial class Program { }
