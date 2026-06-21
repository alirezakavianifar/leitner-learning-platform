import 'package:dio/dio.dart';
import 'package:mobile_app/core/services/storage_service.dart';

/// Preconfigured Dio client setup that injects Authorization headers
/// using the securely stored JWT token when available.
class DioClient {
  final Dio dio;
  final StorageService storageService;

  DioClient({
    required this.dio,
    required this.storageService,
    required String baseUrl,
  }) {
    dio.options.baseUrl = baseUrl;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storageService.readSecure('jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Global error logging/hook
          return handler.next(e);
        },
      ),
    );
  }
}
