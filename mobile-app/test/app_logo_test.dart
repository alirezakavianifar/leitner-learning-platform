import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/core/widgets/app_logo.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';
import 'package:mobile_app/features/config/domain/repositories/config_repository.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';

class FakeConfigRepo implements ConfigRepository {
  RemoteConfig? config;

  FakeConfigRepo(this.config);

  @override
  RemoteConfig? getCachedConfig() => config;

  @override
  Future<Either<Failure, RemoteConfig>> getRemoteConfig() async {
    if (config != null) return Right(config!);
    return Left(ServerFailure('Failed'));
  }
}

void main() {
  testWidgets('AppLogo renders bundled image asset when appLogoUrl is null', (tester) async {
    const config = RemoteConfig(
      maintenanceMode: false,
      apiServer: 'http://localhost:5217/api/v1',
      contentServer: 'http://localhost:5217/api/v1',
      bannerServer: 'http://localhost:5217/api/v1',
      enableAiTutor: false,
      enableCustomThemes: true,
      enableSearchV2: true,
      rotationIntervalSeconds: 4,
      maxBannerCount: 5,
      appLogoSize: 120.0,
      appLogoUrl: null,
    );

    final repo = FakeConfigRepo(config);
    final bloc = ConfigBloc(configRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ConfigBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: AppLogo(),
          ),
        ),
      ),
    );

    // Initial state check
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('AppLogo scales properly when custom size is provided', (tester) async {
    const config = RemoteConfig(
      maintenanceMode: false,
      apiServer: 'http://localhost:5217/api/v1',
      contentServer: 'http://localhost:5217/api/v1',
      bannerServer: 'http://localhost:5217/api/v1',
      enableAiTutor: false,
      enableCustomThemes: true,
      enableSearchV2: true,
      rotationIntervalSeconds: 4,
      maxBannerCount: 5,
      appLogoSize: 110.0,
    );

    final repo = FakeConfigRepo(config);
    final bloc = ConfigBloc(configRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ConfigBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: AppLogo(size: 80.0),
          ),
        ),
      ),
    );

    final sizedContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(Container),
      ).first,
    );

    expect(sizedContainer.constraints?.maxWidth, 80.0);
    expect(sizedContainer.constraints?.maxHeight, 80.0);
  });
}
