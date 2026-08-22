import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';
import 'package:mobile_app/features/config/domain/repositories/config_repository.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_event.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';

class FakeConfigRepository implements ConfigRepository {
  Either<Failure, RemoteConfig>? result;
  RemoteConfig? cached;

  @override
  RemoteConfig? getCachedConfig() => cached;

  @override
  Future<Either<Failure, RemoteConfig>> getRemoteConfig() async {
    return result ?? Left(ServerFailure('No mock result configured'));
  }
}

void main() {
  group('RemoteConfig Entity JSON Mapping', () {
    test('should map json correctly to RemoteConfig entity', () {
      final json = {
        'maintenance_mode': false,
        'endpoints': {
          'api_server': 'https://api.test.com',
          'content_server': 'https://content.test.com',
          'banner_server': 'https://banners.test.com',
        },
        'feature_flags': {
          'enable_ai_tutor': true,
          'enable_custom_themes': false,
          'enable_search_v2': true,
          'enable_gamified_layout': false,
          'enable_screenshot_protection': false,
        },
        'banner_configs': {
          'rotation_interval_seconds': 6,
          'max_banner_count': 4,
        },
        'social_links': {
          'telegram_url': 'https://t.me/CustomApp',
          'bale_url': 'https://ble.ir/customapp',
          'eitaa_url': 'https://eitaa.com/customapp',
          'support_url': 'https://t.me/CustomSupport',
          'support_id': '@CustomSupport',
        },
        'leitner_configs': {
          'box2_interval': 5,
          'box3_interval': 10,
          'box4_interval': 15,
          'box5_interval': 20,
          'interval_unit': 'minutes',
        }
      };

      final config = RemoteConfig.fromJson(json);

      expect(config.maintenanceMode, false);
      expect(config.apiServer, 'https://api.test.com');
      expect(config.contentServer, 'https://content.test.com');
      expect(config.bannerServer, 'https://banners.test.com');
      expect(config.enableAiTutor, true);
      expect(config.enableCustomThemes, false);
      expect(config.enableSearchV2, true);
      expect(config.enableGamifiedLayout, false);
      expect(config.enableScreenshotProtection, false);
      expect(config.rotationIntervalSeconds, 6);
      expect(config.maxBannerCount, 4);
      expect(config.cardNavIconStyle, 'chevron');
      expect(config.telegramUrl, 'https://t.me/CustomApp');
      expect(config.baleUrl, 'https://ble.ir/customapp');
      expect(config.eitaaUrl, 'https://eitaa.com/customapp');
      expect(config.supportUrl, 'https://t.me/CustomSupport');
      expect(config.supportId, '@CustomSupport');
      expect(config.leitnerBox2Interval, 5);
      expect(config.leitnerBox3Interval, 10);
      expect(config.leitnerBox4Interval, 15);
      expect(config.leitnerBox5Interval, 20);
      expect(config.leitnerIntervalUnit, 'minutes');
    });

    test('should return default values when fields are missing', () {
      final json = <String, dynamic>{};
      final config = RemoteConfig.fromJson(json);

      expect(config.maintenanceMode, false);
      expect(config.enableAiTutor, false);
      expect(config.enableCustomThemes, true);
      expect(config.enableSearchV2, true);
      expect(config.enableGamifiedLayout, false);
      expect(config.enableScreenshotProtection, true);
      expect(config.cardNavIconStyle, 'chevron');
      expect(config.telegramUrl, 'https://t.me/RightlearnApp');
      expect(config.baleUrl, 'https://ble.ir/rightlearnapp');
      expect(config.eitaaUrl, 'https://eitaa.com/RightLearnApp');
      expect(config.supportUrl, 'https://t.me/RLAppSupport');
      expect(config.supportId, '@RLAppSupport');
      expect(config.leitnerBox2Interval, 3);
      expect(config.leitnerBox3Interval, 7);
      expect(config.leitnerBox4Interval, 16);
      expect(config.leitnerBox5Interval, 31);
      expect(config.leitnerIntervalUnit, 'days');
    });
  });

  group('ConfigBloc States and Events', () {
    late FakeConfigRepository repository;
    late ConfigBloc bloc;

    setUp(() {
      repository = FakeConfigRepository();
      bloc = ConfigBloc(configRepository: repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state should be ConfigInitial when no cache is available', () {
      expect(bloc.state, const ConfigInitial());
    });

    test('initial state should be ConfigLoaded when cache is available', () {
      const cachedConfig = RemoteConfig(
        maintenanceMode: false,
        apiServer: 'https://api.com',
        contentServer: 'https://content.com',
        bannerServer: 'https://banners.com',
        enableAiTutor: false,
        enableCustomThemes: true,
        enableSearchV2: true,
        enableGamifiedLayout: false,
        rotationIntervalSeconds: 4,
        maxBannerCount: 5,
      );

      final cachedRepo = FakeConfigRepository()..cached = cachedConfig;
      final cachedBloc = ConfigBloc(configRepository: cachedRepo);

      expect(cachedBloc.state, const ConfigLoaded(config: cachedConfig));
      cachedBloc.close();
    });

    test('should emit [ConfigLoading, ConfigLoaded] when config loads successfully and preserve config', () async {
      const config = RemoteConfig(
        maintenanceMode: false,
        apiServer: 'https://api.com',
        contentServer: 'https://content.com',
        bannerServer: 'https://banners.com',
        enableAiTutor: false,
        enableCustomThemes: true,
        enableSearchV2: true,
        enableGamifiedLayout: false,
        rotationIntervalSeconds: 4,
        maxBannerCount: 5,
      );

      repository.result = const Right(config);

      final expectedStates = [
        const ConfigLoading(),
        const ConfigLoaded(config: config),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(LoadConfigEvent());
    });

    test('should emit [ConfigLoading(previousConfig), ConfigLoaded] during reload preserving config', () async {
      const initialConfig = RemoteConfig(
        maintenanceMode: false,
        apiServer: 'https://api.com',
        contentServer: 'https://content.com',
        bannerServer: 'https://banners.com',
        enableAiTutor: false,
        enableCustomThemes: true,
        enableSearchV2: true,
        enableGamifiedLayout: false,
        rotationIntervalSeconds: 4,
        maxBannerCount: 5,
      );

      const updatedConfig = RemoteConfig(
        maintenanceMode: false,
        apiServer: 'https://api.com',
        contentServer: 'https://content.com',
        bannerServer: 'https://banners.com',
        enableAiTutor: true,
        enableCustomThemes: true,
        enableSearchV2: true,
        enableGamifiedLayout: false,
        rotationIntervalSeconds: 4,
        maxBannerCount: 5,
      );

      final repo = FakeConfigRepository()..cached = initialConfig;
      final reloadedBloc = ConfigBloc(configRepository: repo);
      repo.result = const Right(updatedConfig);

      final expectedStates = [
        const ConfigLoading(previousConfig: initialConfig),
        const ConfigLoaded(config: updatedConfig),
      ];

      expectLater(reloadedBloc.stream, emitsInOrder(expectedStates));

      reloadedBloc.add(LoadConfigEvent());
    });

    test('should emit [ConfigLoading, ConfigMaintenance] when maintenance mode is active', () async {
      const config = RemoteConfig(
        maintenanceMode: true,
        apiServer: 'https://api.com',
        contentServer: 'https://content.com',
        bannerServer: 'https://banners.com',
        enableAiTutor: false,
        enableCustomThemes: true,
        enableSearchV2: true,
        enableGamifiedLayout: false,
        rotationIntervalSeconds: 4,
        maxBannerCount: 5,
      );

      repository.result = const Right(config);

      final expectedStates = [
        const ConfigLoading(),
        const ConfigMaintenance(config: config),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(LoadConfigEvent());
    });

    test('should emit [ConfigLoading, ConfigError] when loading config fails', () async {
      repository.result = const Left(ServerFailure('Connection error'));

      final expectedStates = [
        const ConfigLoading(),
        const ConfigError(message: 'Connection error'),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(LoadConfigEvent());
    });
  });
}
