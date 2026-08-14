import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/config/data/datasources/config_remote_data_source.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';
import 'package:mobile_app/features/config/domain/repositories/config_repository.dart';
import 'package:mobile_app/core/network/dio_client.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  final ConfigRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  final DioClient dioClient;

  static const String _kCachedConfigKey = 'cached_remote_config';

  ConfigRepositoryImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
    required this.dioClient,
  });

  @override
  RemoteConfig? getCachedConfig() {
    final cachedJson = sharedPreferences.getString(_kCachedConfigKey);
    if (cachedJson != null) {
      try {
        return RemoteConfig.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<Either<Failure, RemoteConfig>> getRemoteConfig() async {
    try {
      final config = await remoteDataSource.getRemoteConfig();
      // Cache settings locally
      await sharedPreferences.setString(_kCachedConfigKey, jsonEncode(config.toJson()));
      
      // Update dynamic endpoints (only if not overridden at compile time)
      const customUrl = String.fromEnvironment('API_BASE_URL');
      if (config.apiServer.isNotEmpty && customUrl.isEmpty) {
        dioClient.updateBaseUrl(config.apiServer);
      }
      
      return Right(config);
    } catch (e) {
      // Fallback to cached configuration if network is down
      final config = getCachedConfig();
      if (config != null) {
        // Still apply endpoints if we had cached values (and no compile-time override)
        const customUrl = String.fromEnvironment('API_BASE_URL');
        if (config.apiServer.isNotEmpty && customUrl.isEmpty) {
          dioClient.updateBaseUrl(config.apiServer);
        }
        
        return Right(config);
      }
      return Left(ServerFailure(e.toString()));
    }
  }
}
