import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:dio/dio.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/core/network/correlation_interceptor.dart';

/// Preconfigured Dio client setup that injects Authorization headers
/// using the securely stored JWT token when available.
class DioClient {
  final Dio dio;
  final StorageService storageService;

  /// Called when the server returns 401 Unauthorized.
  /// Use this to clear credentials and redirect the user to the login screen.
  final VoidCallback? onUnauthorized;

  bool _isFailoverInProgress = false;

  DioClient({
    required this.dio,
    required this.storageService,
    required String baseUrl,
    this.onUnauthorized,
  }) {
    var sanitizedBaseUrl = baseUrl;
    if (!sanitizedBaseUrl.endsWith('/')) {
      sanitizedBaseUrl = '$sanitizedBaseUrl/';
    }
    if (sanitizedBaseUrl.isNotEmpty && sanitizedBaseUrl != '/') {
      dio.options.baseUrl = sanitizedBaseUrl;
    } else {
      dio.options.baseUrl = 'http://localhost/';
    }
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    dio.interceptors.add(CorrelationInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.startsWith('/')) {
            options.path = options.path.substring(1);
          }
          final token = await storageService.readSecure('jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle 401 Unauthorized — clear token and redirect to login
          if (e.response?.statusCode == 401) {
            await storageService.deleteSecure('jwt_token');
            onUnauthorized?.call();
            return handler.next(e);
          }

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
    var resolvedUrl = newUrl;
    if (kIsWeb || (!kIsWeb && Platform.isWindows)) {
      resolvedUrl = resolvedUrl.replaceAll('10.0.2.2', 'localhost');
    } else {
      resolvedUrl = resolvedUrl.replaceAll('localhost', '10.0.2.2');
    }
    if (!resolvedUrl.endsWith('/')) {
      resolvedUrl = '$resolvedUrl/';
    }
    dio.options.baseUrl = resolvedUrl;
  }

  Future<bool> _attemptFailover() async {
    if (_isFailoverInProgress) return false;
    _isFailoverInProgress = true;

    final fallbacks = [
      'http://10.0.2.2:5217/api/v1',
      'http://localhost:5217/api/v1',
      'http://10.0.2.2:8080/api/v1',
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
