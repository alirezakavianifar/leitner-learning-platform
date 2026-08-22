import 'package:equatable/equatable.dart';

class RemoteConfig extends Equatable {
  final bool maintenanceMode;
  final String apiServer;
  final String contentServer;
  final String bannerServer;
  final bool enableAiTutor;
  final bool enableCustomThemes;
  final bool enableSearchV2;
  final bool enableGamifiedLayout;
  final bool enableScreenshotProtection;
  final int rotationIntervalSeconds;
  final int maxBannerCount;
  final String cardNavIconStyle;
  final String telegramUrl;
  final String baleUrl;
  final String eitaaUrl;
  final String supportUrl;
  final String supportId;

  const RemoteConfig({
    required this.maintenanceMode,
    required this.apiServer,
    required this.contentServer,
    required this.bannerServer,
    required this.enableAiTutor,
    required this.enableCustomThemes,
    required this.enableSearchV2,
    this.enableGamifiedLayout = false,
    this.enableScreenshotProtection = true,
    required this.rotationIntervalSeconds,
    required this.maxBannerCount,
    this.cardNavIconStyle = 'chevron',
    this.telegramUrl = 'https://t.me/RightlearnApp',
    this.baleUrl = 'https://ble.ir/rightlearnapp',
    this.eitaaUrl = 'https://eitaa.com/RightLearnApp',
    this.supportUrl = 'https://t.me/RLAppSupport',
    this.supportId = '@RLAppSupport',
  });

  @override
  List<Object?> get props => [
        maintenanceMode,
        apiServer,
        contentServer,
        bannerServer,
        enableAiTutor,
        enableCustomThemes,
        enableSearchV2,
        enableGamifiedLayout,
        enableScreenshotProtection,
        rotationIntervalSeconds,
        maxBannerCount,
        cardNavIconStyle,
        telegramUrl,
        baleUrl,
        eitaaUrl,
        supportUrl,
        supportId,
      ];

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final endpoints = json['endpoints'] as Map<String, dynamic>? ?? {};
    final featureFlags = json['feature_flags'] as Map<String, dynamic>? ?? {};
    final bannerConfigs = json['banner_configs'] as Map<String, dynamic>? ?? {};
    final appStyles = json['app_styles'] as Map<String, dynamic>? ?? {};
    final socialLinks = json['social_links'] as Map<String, dynamic>? ?? {};

    return RemoteConfig(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      apiServer: endpoints['api_server'] as String? ?? 'http://10.0.2.2:8080/api/v1',
      contentServer: endpoints['content_server'] as String? ?? 'http://10.0.2.2:8080/api/v1',
      bannerServer: endpoints['banner_server'] as String? ?? 'http://10.0.2.2:8080/api/v1',
      enableAiTutor: featureFlags['enable_ai_tutor'] as bool? ?? false,
      enableCustomThemes: featureFlags['enable_custom_themes'] as bool? ?? true,
      enableSearchV2: featureFlags['enable_search_v2'] as bool? ?? true,
      enableGamifiedLayout: featureFlags['enable_gamified_layout'] as bool? ?? false,
      enableScreenshotProtection: featureFlags['enable_screenshot_protection'] as bool? ?? true,
      rotationIntervalSeconds: bannerConfigs['rotation_interval_seconds'] as int? ?? 4,
      maxBannerCount: bannerConfigs['max_banner_count'] as int? ?? 5,
      cardNavIconStyle: json['card_nav_icon_style'] as String? ??
          appStyles['card_nav_icon_style'] as String? ??
          'chevron',
      telegramUrl: json['telegram_url'] as String? ??
          socialLinks['telegram_url'] as String? ??
          'https://t.me/RightlearnApp',
      baleUrl: json['bale_url'] as String? ??
          socialLinks['bale_url'] as String? ??
          'https://ble.ir/rightlearnapp',
      eitaaUrl: json['eitaa_url'] as String? ??
          socialLinks['eitaa_url'] as String? ??
          'https://eitaa.com/RightLearnApp',
      supportUrl: json['support_url'] as String? ??
          socialLinks['support_url'] as String? ??
          'https://t.me/RLAppSupport',
      supportId: json['support_id'] as String? ??
          socialLinks['support_id'] as String? ??
          '@RLAppSupport',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenance_mode': maintenanceMode,
      'card_nav_icon_style': cardNavIconStyle,
      'telegram_url': telegramUrl,
      'bale_url': baleUrl,
      'eitaa_url': eitaaUrl,
      'support_url': supportUrl,
      'support_id': supportId,
      'endpoints': {
        'api_server': apiServer,
        'content_server': contentServer,
        'banner_server': bannerServer,
      },
      'feature_flags': {
        'enable_ai_tutor': enableAiTutor,
        'enable_custom_themes': enableCustomThemes,
        'enable_search_v2': enableSearchV2,
        'enable_gamified_layout': enableGamifiedLayout,
        'enable_screenshot_protection': enableScreenshotProtection,
      },
      'app_styles': {
        'card_nav_icon_style': cardNavIconStyle,
      },
      'banner_configs': {
        'rotation_interval_seconds': rotationIntervalSeconds,
        'max_banner_count': maxBannerCount,
      },
      'social_links': {
        'telegram_url': telegramUrl,
        'bale_url': baleUrl,
        'eitaa_url': eitaaUrl,
        'support_url': supportUrl,
        'support_id': supportId,
      },
    };
  }
}
