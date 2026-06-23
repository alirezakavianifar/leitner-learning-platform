import 'package:dio/dio.dart';
import 'package:mobile_app/core/services/storage_service.dart';

/// Preconfigured Dio client setup that injects Authorization headers
/// using the securely stored JWT token when available.
class DioClient {
  final Dio dio;
  final StorageService storageService;
  bool _isFailoverInProgress = false;

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
        onError: (DioException e, handler) async {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError) {
            
            final success = await _attemptFailover();
            if (success) {
              final newOptions = e.requestOptions;
              newOptions.baseUrl = dio.options.baseUrl;
              try {
                final response = await dio.fetch(newOptions);
                return handler.resolve(response);
              } catch (_) {
                return handler.next(e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
  }

  Future<bool> _attemptFailover() async {
    if (_isFailoverInProgress) return false;
    _isFailoverInProgress = true;

    final fallbacks = [
      'http://10.0.2.2:8080/api/v1',
      'http://localhost:5000/api/v1',
      'http://localhost:8080/api/v1',
    ];

    final currentUrl = dio.options.baseUrl;
    
    for (final url in fallbacks) {
      if (url == currentUrl) continue;
      
      try {
        final tempDio = Dio(BaseOptions(
          baseUrl: url,
          connectTimeout: const Duration(seconds: 3),
        ));
        
        final response = await tempDio.get('/');
        if (response.statusCode == 200) {
          dio.options.baseUrl = url;
          _isFailoverInProgress = false;
          return true;
        }
      } catch (_) {
        // Try next fallback URL
      }
    }

    _isFailoverInProgress = false;
    return false;
  }
}
