import 'package:flutter/material.dart';
import '../../features/config/domain/entities/remote_config.dart';

/// Central helper for accessing responsive, admin-configured icon sizes.
class AppIconSizes {
  static const double defaultCardNavSize = 20.0;
  static const double defaultBottomNavSize = 26.0;
  static const double defaultAppBarIconSize = 24.0;
  static const double defaultAppLogoSize = 110.0;
  static const double defaultScale = 1.0;

  /// Returns the configured or default card navigation icon size.
  static double getCardNavIconSize(RemoteConfig? config) {
    if (config == null) return defaultCardNavSize;
    return config.cardNavIconSize > 0 ? config.cardNavIconSize : defaultCardNavSize;
  }

  /// Returns the configured or default bottom navigation bar icon size.
  static double getBottomNavIconSize(RemoteConfig? config) {
    if (config == null) return defaultBottomNavSize;
    return config.bottomNavIconSize > 0 ? config.bottomNavIconSize : defaultBottomNavSize;
  }

  /// Returns the configured or default app bar action icon size.
  static double getAppBarIconSize(RemoteConfig? config) {
    if (config == null) return defaultAppBarIconSize;
    return config.appBarIconSize > 0 ? config.appBarIconSize : defaultAppBarIconSize;
  }

  /// Returns the configured or default in-app logo / branding icon size.
  static double getAppLogoSize(RemoteConfig? config) {
    if (config == null) return defaultAppLogoSize;
    return config.appLogoSize > 0 ? config.appLogoSize : defaultAppLogoSize;
  }

  /// Scales a given base icon size using the global icon scale multiplier.
  static double scale(double baseSize, RemoteConfig? config) {
    final scaleFactor = (config != null && config.globalIconScale > 0)
        ? config.globalIconScale
        : defaultScale;
    return baseSize * scaleFactor;
  }
}
