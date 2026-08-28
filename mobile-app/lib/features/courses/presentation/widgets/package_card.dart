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
    final borderColor = package.isPurchased
        ? AppColors.courseDownloaded
        : const Color(0xFFFFB300);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Package Visual Icon / Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: package.isPurchased
                            ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                            : [const Color(0xFFFF9800), const Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: (package.isPurchased ? const Color(0xFF2E7D32) : const Color(0xFFFF5722)).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        package.isPurchased ? Icons.verified : Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Package Meta & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title & Status Icon / Discount Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              package.title,
                              textDirection: RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(package.title)
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (package.isPurchased)
                            Icon(
                              Icons.offline_pin,
                              color: AppColors.courseDownloaded,
                              size: 16,
                            )
                          else if (package.discountPercentage > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE91E63).withOpacity(0.5)),
                              ),
                              child: Text(
                                '${package.discountPercentage}٪',
                                style: const TextStyle(
                                  color: Color(0xFFFF4081),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFFFB300),
                              size: 16,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Meta row (Courses count, total cards count, price)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_outlined, size: 10, color: Color(0xFFFF9800)),
                                const SizedBox(width: 3),
                                Text(
                                  loc.translate('courses_included').replaceAll('{count}', '${package.courses.length}'),
                                  style: const TextStyle(
                                    color: Color(0xFFFF9800),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${package.totalCardCount} ${loc.cardsCount}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                          const Spacer(),
                          if (package.originalPrice != null &&
                              package.originalPrice! > package.price &&
                              !package.isPurchased) ...[
                            Text(
                              _formatPrice(package.originalPrice!, context),
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.7),
                                fontSize: 9.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _formatPrice(package.price, context),
                            style: TextStyle(
                              color: package.price == 0 ? AppColors.secondary : const Color(0xFFFFB300),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Bottom actions row: Details modal hint + Action button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: onTap,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 11, color: AppColors.textSecondary.withOpacity(0.7)),
                                const SizedBox(width: 3),
                                Text(
                                  loc.translate('more_info_hint'),
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withOpacity(0.7),
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 26,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                backgroundColor: package.isPurchased
                                    ? (isDark
                                        ? const Color(0xFF1B5E20).withOpacity(0.3)
                                        : const Color(0xFFE8F5E9))
                                    : const Color(0xFFFF9800),
                                foregroundColor: package.isPurchased
                                    ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                                    : Colors.white,
                                side: package.isPurchased
                                    ? BorderSide(
                                        color: isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
                                        width: 1,
                                      )
                                    : null,
                                elevation: 0,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: package.isPurchased ? onTap : onPurchase,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    package.isPurchased ? Icons.visibility : Icons.shopping_cart_checkout,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    package.isPurchased
                                        ? loc.translate('view_bundle')
                                        : loc.translate('purchase_bundle'),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
