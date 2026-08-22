import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';

class PackageCard extends StatelessWidget {
  final CoursePackage package;
  final VoidCallback onTap;
  final VoidCallback onPurchase;

  const PackageCard({
    Key? key,
    required this.package,
    required this.onTap,
    required this.onPurchase,
  }) : super(key: key);

  String _formatPrice(double price, BuildContext context) {
    if (price == 0) {
      return AppLocalizations.of(context).free;
    }
    final formattedNumber = price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formattedNumber ${AppLocalizations.of(context).toman}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E2640),
                  const Color(0xFF151928),
                ]
              : [
                  const Color(0xFFF3F5FA),
                  const Color(0xFFE8ECF5),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: package.isPurchased
              ? AppColors.courseDownloaded
              : const Color(0xFFFFB300).withOpacity(0.6),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (package.isPurchased
                    ? AppColors.courseDownloaded
                    : const Color(0xFFFFB300))
                .withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bundle Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5722).withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            loc.translate('bundle_badge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Discount / Status Chip
                    if (package.isPurchased)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.courseDownloaded.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.courseDownloaded),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: AppColors.courseDownloaded, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              loc.translate('all_courses_in_bundle_unlocked'),
                              style: TextStyle(
                                color: AppColors.courseDownloaded,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (package.discountPercentage > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE91E63).withOpacity(0.6)),
                        ),
                        child: Text(
                          loc.translate('save_amount').replaceAll('{percent}', '${package.discountPercentage}'),
                          style: const TextStyle(
                            color: Color(0xFFFF4081),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  package.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (package.description != null && package.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    package.description!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),

                // Included Courses Summary Cards
                if (package.courses.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              loc.translate('courses_included').replaceAll('{count}', '${package.courses.length}'),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${package.totalCardCount} ${loc.cardsCount}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: package.courses.map((c) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.isPurchased
                                    ? AppColors.courseDownloaded.withOpacity(0.15)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: c.isPurchased
                                      ? AppColors.courseDownloaded.withOpacity(0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (c.isPurchased) ...[
                                    Icon(Icons.check, size: 12, color: AppColors.courseDownloaded),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    c.title,
                                    style: TextStyle(
                                      color: c.isPurchased
                                          ? AppColors.courseDownloaded
                                          : AppColors.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const Divider(color: Color(0xFF333E56), height: 1),
                const SizedBox(height: 14),

                // Pricing and Action Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (package.originalPrice != null &&
                            package.originalPrice! > package.price &&
                            !package.isPurchased)
                          Text(
                            _formatPrice(package.originalPrice!, context),
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          _formatPrice(package.price, context),
                          style: TextStyle(
                            color: package.price == 0 ? AppColors.secondary : const Color(0xFFFFB300),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: package.isPurchased
                            ? AppColors.surface
                            : const Color(0xFFFF9800),
                        foregroundColor: package.isPurchased
                            ? AppColors.textPrimary
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: package.isPurchased ? 0 : 3,
                      ),
                      onPressed: package.isPurchased ? onTap : onPurchase,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            package.isPurchased ? Icons.visibility : Icons.shopping_cart_checkout,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            package.isPurchased
                                ? loc.translate('view_bundle')
                                : loc.translate('purchase_bundle'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
