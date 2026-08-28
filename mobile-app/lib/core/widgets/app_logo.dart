import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/constants/app_icon_sizes.dart';
import 'package:mobile_app/core/utils/image_url_resolver.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';

/// Reusable application branding logo widget that seamlessly switches between
/// remote dynamic branding uploaded by admin and local bundled fallback assets.
class AppLogo extends StatelessWidget {
  final double? size;
  final double? borderRadius;
  final bool showShadow;
  final BoxFit fit;

  const AppLogo({
    Key? key,
    this.size,
    this.borderRadius,
    this.showShadow = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigBloc, ConfigState>(
      builder: (context, state) {
        final config = state.config;
        final double effectiveSize = size ?? AppIconSizes.getAppLogoSize(config);
        final double effectiveRadius = borderRadius ?? (effectiveSize * 0.25).clamp(12.0, 36.0);
        final String? rawLogoUrl = config?.appLogoUrl;
        final String? resolvedUrl = resolveImageUrl(rawLogoUrl);

        Widget imageWidget;
        if (resolvedUrl != null &&
            (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://'))) {
          imageWidget = Image.network(
            resolvedUrl,
            width: effectiveSize,
            height: effectiveSize,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallbackAsset(effectiveSize),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: effectiveSize,
                height: effectiveSize,
                color: AppColors.primary.withOpacity(0.1),
                child: Center(
                  child: SizedBox(
                    width: effectiveSize * 0.3,
                    height: effectiveSize * 0.3,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          imageWidget = _buildFallbackAsset(effectiveSize);
        }

        return Container(
          width: effectiveSize,
          height: effectiveSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(effectiveRadius),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: imageWidget,
          ),
        );
      },
    );
  }

  Widget _buildFallbackAsset(double effectiveSize) {
    return Image.asset(
      'assets/images/app_icon.webp',
      width: effectiveSize,
      height: effectiveSize,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: effectiveSize,
        height: effectiveSize,
        color: AppColors.primary,
        child: Icon(
          Icons.school,
          size: effectiveSize * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
