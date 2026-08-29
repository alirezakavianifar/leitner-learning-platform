using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using LeitnerPlatform.Data;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.API.Controllers.v1
{
    [Authorize]
    [ApiController]
    [Route("api/v1/packages")]
    [EnableRateLimiting("GeneralRateLimit")]
    public class PackageController : ControllerBase
    {
        private readonly LeitnerDbContext _context;

        public PackageController(LeitnerDbContext context)
        {
            _context = context;
        }

        private Guid GetUserId()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                            ?? User.FindFirst("sub")?.Value;

            if (Guid.TryParse(userIdStr, out var id))
            {
                return id;
            }

            return Guid.Empty;
        }

        [AllowAnonymous]
        [HttpGet]
        public async Task<IActionResult> GetPackages()
        {
            var userId = GetUserId();
            var completedCoursePurchases = new List<Guid>();
            var completedPackagePurchases = new List<Guid>();

            if (userId != Guid.Empty)
            {
                // User's completed individual course purchases
                completedCoursePurchases = await _context.Purchases
                    .AsNoTracking()
                    .Where(p => p.UserId == userId && p.Status == "COMPLETED")
                    .Select(p => p.CourseId)
                    .ToListAsync();

                // Completed package purchases
                completedPackagePurchases = await _context.PackagePurchases
                    .AsNoTracking()
                    .Where(p => p.UserId == userId && p.Status == "COMPLETED")
                    .Select(p => p.PackageId)
                    .ToListAsync();
            }

            var packages = await _context.CoursePackages
                .AsNoTracking()
                .Where(p => p.IsPublished && !p.IsArchived)
                .Include(p => p.Items)
                    .ThenInclude(i => i.Course)
                .OrderBy(p => p.DisplayOrder)
                .ThenByDescending(p => p.CreatedAt)
                .ToListAsync();

            var result = packages.Select(pkg =>
            {
                var validItems = pkg.Items
                    .Where(i => i.Course != null && (i.Course.IsPublished || completedCoursePurchases.Contains(i.CourseId)))
                    .OrderBy(i => i.DisplayOrder)
                    .ToList();

                var courseDtos = validItems.Select(i =>
                {
                    var c = i.Course!;
                    var isCoursePurchased = c.Price == 0 || completedCoursePurchases.Contains(c.Id);
                    return new
                    {
                        id = c.Id,
                        title = c.Title,
                        description = c.Description,
                        category = c.Category,
                        difficulty = c.Difficulty,
                        price = c.Price,
                        card_count = c.CardCount,
                        image_url = c.ImageUrl,
                        is_purchased = isCoursePurchased,
                        version = c.Version
                    };
                }).ToList();

                var totalCardCount = validItems.Sum(i => i.Course?.CardCount ?? 0);
                var sumIndividualPrices = validItems.Sum(i => i.Course?.Price ?? 0m);
                var originalPrice = pkg.OriginalPrice ?? (sumIndividualPrices > pkg.Price ? sumIndividualPrices : (decimal?)null);
                
                var discountPercent = 0;
                if (originalPrice.HasValue && originalPrice.Value > pkg.Price && originalPrice.Value > 0)
                {
                    discountPercent = (int)Math.Round((1.0m - (pkg.Price / originalPrice.Value)) * 100m);
                }

                var ownedCoursesCount = courseDtos.Count(c => c.is_purchased);
                var isFullyOwned = courseDtos.Count > 0 && ownedCoursesCount == courseDtos.Count;
                var isPackagePurchased = completedPackagePurchases.Contains(pkg.Id) || isFullyOwned;

                return new
                {
                    id = pkg.Id,
                    title = pkg.Title,
                    description = pkg.Description,
                    category = pkg.Category,
                    price = pkg.Price,
                    original_price = originalPrice,
                    image_url = pkg.ImageUrl,
                    discount_percentage = discountPercent,
                    total_card_count = totalCardCount,
                    is_purchased = isPackagePurchased,
                    courses_count = courseDtos.Count,
                    owned_courses_count = ownedCoursesCount,
                    courses = courseDtos,
                    created_at = pkg.CreatedAt,
                    updated_at = pkg.UpdatedAt
                };
            });

            return Ok(result);
        }

        [AllowAnonymous]
        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetPackage(Guid id)
        {
            var userId = GetUserId();

            var pkg = await _context.CoursePackages
                .Include(p => p.Items)
                    .ThenInclude(i => i.Course)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (pkg == null || (!pkg.IsPublished && !User.IsInRole("Admin")))
            {
                return NotFound(new { success = false, message = "Package not found." });
            }

            var completedCoursePurchases = new List<Guid>();
            bool isPackagePurchased = false;

            if (userId != Guid.Empty)
            {
                completedCoursePurchases = await _context.Purchases
                    .Where(p => p.UserId == userId && p.Status == "COMPLETED")
                    .Select(p => p.CourseId)
                    .ToListAsync();

                isPackagePurchased = await _context.PackagePurchases
                    .AnyAsync(p => p.UserId == userId && p.PackageId == id && p.Status == "COMPLETED");
            }

            var validItems = pkg.Items
                .Where(i => i.Course != null)
                .OrderBy(i => i.DisplayOrder)
                .ToList();

            var courseDtos = validItems.Select(i =>
            {
                var c = i.Course!;
                var isCoursePurchased = c.Price == 0 || completedCoursePurchases.Contains(c.Id);
                return new
                {
                    id = c.Id,
                    title = c.Title,
                    description = c.Description,
                    category = c.Category,
                    difficulty = c.Difficulty,
                    price = c.Price,
                    card_count = c.CardCount,
                    image_url = c.ImageUrl,
                    is_purchased = isCoursePurchased,
                    version = c.Version
                };
            }).ToList();

            var totalCardCount = validItems.Sum(i => i.Course?.CardCount ?? 0);
            var sumIndividualPrices = validItems.Sum(i => i.Course?.Price ?? 0m);
            var originalPrice = pkg.OriginalPrice ?? (sumIndividualPrices > pkg.Price ? sumIndividualPrices : (decimal?)null);
            
            var discountPercent = 0;
            if (originalPrice.HasValue && originalPrice.Value > pkg.Price && originalPrice.Value > 0)
            {
                discountPercent = (int)Math.Round((1.0m - (pkg.Price / originalPrice.Value)) * 100m);
            }

            var ownedCoursesCount = courseDtos.Count(c => c.is_purchased);
            var isFullyOwned = courseDtos.Count > 0 && ownedCoursesCount == courseDtos.Count;

            return Ok(new
            {
                id = pkg.Id,
                title = pkg.Title,
                description = pkg.Description,
                category = pkg.Category,
                price = pkg.Price,
                original_price = originalPrice,
                image_url = pkg.ImageUrl,
                discount_percentage = discountPercent,
                total_card_count = totalCardCount,
                is_purchased = isPackagePurchased || isFullyOwned,
                courses_count = courseDtos.Count,
                owned_courses_count = ownedCoursesCount,
                courses = courseDtos,
                created_at = pkg.CreatedAt,
                updated_at = pkg.UpdatedAt
            });
        }
    }
}
