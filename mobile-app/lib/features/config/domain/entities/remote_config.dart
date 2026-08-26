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
  final double globalIconScale;
  final double cardNavIconSize;
  final double bottomNavIconSize;
  final double appBarIconSize;
  final double appLogoSize;
  final String? appLogoUrl;
  final String telegramUrl;
  final String baleUrl;
  final String eitaaUrl;
  final String supportUrl;
  final String supportId;
  final int leitnerBox2Interval;
  final int leitnerBox3Interval;
  final int leitnerBox4Interval;
  final int leitnerBox5Interval;
  final String leitnerIntervalUnit;

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
    this.globalIconScale = 1.0,
    this.cardNavIconSize = 20.0,
    this.bottomNavIconSize = 26.0,
    this.appBarIconSize = 24.0,
    this.appLogoSize = 110.0,
    this.appLogoUrl,
    this.telegramUrl = 'https://t.me/RightlearnApp',
    this.baleUrl = 'https://ble.ir/rightlearnapp',
    this.eitaaUrl = 'https://eitaa.com/RightLearnApp',
    this.supportUrl = 'https://t.me/RLAppSupport',
    this.supportId = '@RLAppSupport',
    this.leitnerBox2Interval = 3,
    this.leitnerBox3Interval = 7,
    this.leitnerBox4Interval = 16,
    this.leitnerBox5Interval = 31,
    this.leitnerIntervalUnit = 'days',
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
        globalIconScale,
        cardNavIconSize,
        bottomNavIconSize,
        appBarIconSize,
        appLogoSize,
        appLogoUrl,
        telegramUrl,
        baleUrl,
        eitaaUrl,
        supportUrl,
        supportId,
        leitnerBox2Interval,
        leitnerBox3Interval,
        leitnerBox4Interval,
        leitnerBox5Interval,
        leitnerIntervalUnit,
      ];

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final endpoints = json['endpoints'] as Map<String, dynamic>? ?? {};
    final featureFlags = json['feature_flags'] as Map<String, dynamic>? ?? {};
    final bannerConfigs = json['banner_configs'] as Map<String, dynamic>? ?? {};
    final leitnerConfigs = json['leitner_configs'] as Map<String, dynamic>? ?? {};
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
      globalIconScale: (json['global_icon_scale'] as num?)?.toDouble() ??
          (appStyles['global_icon_scale'] as num?)?.toDouble() ??
          1.0,
      cardNavIconSize: (json['card_nav_icon_size'] as num?)?.toDouble() ??
          (appStyles['card_nav_icon_size'] as num?)?.toDouble() ??
          20.0,
      bottomNavIconSize: (json['bottom_nav_icon_size'] as num?)?.toDouble() ??
          (appStyles['bottom_nav_icon_size'] as num?)?.toDouble() ??
          26.0,
      appBarIconSize: (json['app_bar_icon_size'] as num?)?.toDouble() ??
          (appStyles['app_bar_icon_size'] as num?)?.toDouble() ??
          24.0,
      appLogoSize: (json['app_logo_size'] as num?)?.toDouble() ??
          (appStyles['app_logo_size'] as num?)?.toDouble() ??
          110.0,
      appLogoUrl: json['app_logo_url'] as String? ??
          appStyles['app_logo_url'] as String?,
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
      leitnerBox2Interval: (leitnerConfigs['box2_interval'] as num?)?.toInt() ??
          (json['leitner_box2_interval'] as num?)?.toInt() ??
          3,
      leitnerBox3Interval: (leitnerConfigs['box3_interval'] as num?)?.toInt() ??
          (json['leitner_box3_interval'] as num?)?.toInt() ??
          7,
      leitnerBox4Interval: (leitnerConfigs['box4_interval'] as num?)?.toInt() ??
          (json['leitner_box4_interval'] as num?)?.toInt() ??
          16,
      leitnerBox5Interval: (leitnerConfigs['box5_interval'] as num?)?.toInt() ??
          (json['leitner_box5_interval'] as num?)?.toInt() ??
          31,
      leitnerIntervalUnit: (leitnerConfigs['interval_unit'] as String?) ??
          (json['leitner_interval_unit'] as String?) ??
          'days',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenance_mode': maintenanceMode,
      'card_nav_icon_style': cardNavIconStyle,
      'global_icon_scale': globalIconScale,
      'card_nav_icon_size': cardNavIconSize,
      'bottom_nav_icon_size': bottomNavIconSize,
      'app_bar_icon_size': appBarIconSize,
      'app_logo_size': appLogoSize,
      'app_logo_url': appLogoUrl,
      'telegram_url': telegramUrl,
      'bale_url': baleUrl,
      'eitaa_url': eitaaUrl,
      'support_url': supportUrl,
      'support_id': supportId,
      'leitner_box2_interval': leitnerBox2Interval,
      'leitner_box3_interval': leitnerBox3Interval,
      'leitner_box4_interval': leitnerBox4Interval,
      'leitner_box5_interval': leitnerBox5Interval,
      'leitner_interval_unit': leitnerIntervalUnit,
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
        'global_icon_scale': globalIconScale,
        'card_nav_icon_size': cardNavIconSize,
        'bottom_nav_icon_size': bottomNavIconSize,
        'app_bar_icon_size': appBarIconSize,
        'app_logo_size': appLogoSize,
        'app_logo_url': appLogoUrl,
      },
      'banner_configs': {
        'rotation_interval_seconds': rotationIntervalSeconds,
        'max_banner_count': maxBannerCount,
      },
      'leitner_configs': {
        'box2_interval': leitnerBox2Interval,
        'box3_interval': leitnerBox3Interval,
        'box4_interval': leitnerBox4Interval,
        'box5_interval': leitnerBox5Interval,
        'interval_unit': leitnerIntervalUnit,
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
