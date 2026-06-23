import 'package:dio/dio.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';

abstract class ConfigRemoteDataSource {
  Future<RemoteConfig> getRemoteConfig();
}

class ConfigRemoteDataSourceImpl implements ConfigRemoteDataSource {
  final DioClient dioClient;

  ConfigRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<RemoteConfig> getRemoteConfig() async {
    final response = await dioClient.dio.get('/config/features');
    if (response.statusCode == 200) {
      return RemoteConfig.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }
}
