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
  final String? flavor;

  bool _isFailoverInProgress = false;
  bool _isRefreshingToken = false;
  Future<_TokenRefreshResult>? _refreshTokenFuture;

  DioClient({
    required this.dio,
    required this.storageService,
    required String baseUrl,
    this.onUnauthorized,
    this.flavor,
  }) {
    dio.options.baseUrl = normalizeApiBaseUrl(baseUrl);
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 20);
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (flavor != null && flavor!.isNotEmpty) 'X-App-Platform': flavor,
    };

    dio.interceptors.add(CorrelationInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.startsWith('http://') || options.path.startsWith('https://')) {
            // Absolute URL provided, leave untouched
          } else if (options.path.startsWith('/courses/') && options.path.endsWith('.zip')) {
            // Static course package file: resolve to root host origin (bypasses /api/v1 prefix)
            try {
              final uri = Uri.parse(dio.options.baseUrl);
              final rootOrigin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
              options.baseUrl = rootOrigin;
            } catch (_) {}
          } else if (options.path.startsWith('/')) {
            options.path = options.path.substring(1);
          }
          final token = await storageService.readSecure('jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (flavor != null && flavor!.isNotEmpty) {
            options.headers['X-App-Platform'] = flavor;
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle 401 Unauthorized — attempt token refresh before logging out
          if (e.response?.statusCode == 401) {
            final isAuthEndpoint = e.requestOptions.path.contains('/auth/refresh') ||
                e.requestOptions.path.contains('/auth/otp') ||
                e.requestOptions.path.contains('/auth/captcha');

            if (!isAuthEndpoint) {
              final refreshResult = await _performTokenRefresh();
              if (refreshResult.status == _RefreshStatus.success && refreshResult.token != null) {
                // Retry failed request with new token
                final newOptions = e.requestOptions;
                newOptions.headers['Authorization'] = 'Bearer ${refreshResult.token}';
                try {
                  final retryResponse = await dio.fetch(newOptions);
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  if (retryError is DioException) {
                    return handler.next(retryError);
                  }
                }
              } else if (refreshResult.status == _RefreshStatus.networkError) {
                // Temporary network or server glitch: do NOT log the user out
                return handler.next(e);
              }
            }

            // Only if refresh token is genuinely invalid or revoked: clear credentials and redirect to login
            await storageService.deleteSecure('jwt_token');
            await storageService.deleteSecure('refresh_token');
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

  Future<_TokenRefreshResult> _performTokenRefresh() async {
    if (_isRefreshingToken && _refreshTokenFuture != null) {
      return await _refreshTokenFuture!;
    }

    _isRefreshingToken = true;
    _refreshTokenFuture = _executeRefresh();

    try {
      final result = await _refreshTokenFuture!;
      return result;
    } finally {
      _isRefreshingToken = false;
      _refreshTokenFuture = null;
    }
  }

  Future<_TokenRefreshResult> _executeRefresh() async {
    final refreshToken = await storageService.readSecure('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      return const _TokenRefreshResult(status: _RefreshStatus.invalidRefreshToken);
    }

    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await refreshDio.post(
        'auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        final newJwt = data['token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newJwt != null && newJwt.isNotEmpty) {
          await storageService.writeSecure('jwt_token', newJwt);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await storageService.writeSecure('refresh_token', newRefreshToken);
          }
          return _TokenRefreshResult(status: _RefreshStatus.success, token: newJwt);
        }
      }
      return const _TokenRefreshResult(status: _RefreshStatus.invalidRefreshToken);
    } on DioException catch (dioErr) {
      // Explicit 400 or 401 response from server means refresh token is invalid or expired
      if (dioErr.response?.statusCode == 401 || dioErr.response?.statusCode == 400) {
        return const _TokenRefreshResult(status: _RefreshStatus.invalidRefreshToken);
      }
      // Connection timeouts, network down, 5xx server errors
      return const _TokenRefreshResult(status: _RefreshStatus.networkError);
    } catch (_) {
      return const _TokenRefreshResult(status: _RefreshStatus.networkError);
    }
  }

  /// Normalizes any input API URL to guarantee a valid, trailing-slashed /api/v1/ prefix.
  static String normalizeApiBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      return 'http://localhost:5217/api/v1/';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api/v1') && !url.endsWith('api/v1')) {
      url = '$url/api/v1';
    }
    return '$url/';
  }

  void updateBaseUrl(String newUrl) {
    var resolvedUrl = newUrl;
    if (kIsWeb || (!kIsWeb && Platform.isWindows)) {
      resolvedUrl = resolvedUrl.replaceAll('10.0.2.2', 'localhost');
    } else {
      resolvedUrl = resolvedUrl.replaceAll('localhost', '10.0.2.2');
    }
    dio.options.baseUrl = normalizeApiBaseUrl(resolvedUrl);
  }

  Future<bool> _attemptFailover() async {
    if (_isFailoverInProgress) return false;
    _isFailoverInProgress = true;

    final currentUrl = dio.options.baseUrl.toLowerCase();
    final currentIsRemote = !currentUrl.contains('localhost') &&
                            !currentUrl.contains('10.0.2.2') &&
                            !currentUrl.contains('127.0.0.1');

    // Never failover a valid remote production server to internal local loopbacks
    if (currentIsRemote) {
      _isFailoverInProgress = false;
      return false;
    }

    final fallbacks = [
      'http://10.0.2.2:5217/api/v1',
      'http://localhost:5217/api/v1',
      'http://10.0.2.2:8080/api/v1',
      'http://localhost:8080/api/v1',
    ];

    for (final url in fallbacks) {
      if (url.toLowerCase() == currentUrl) continue;
      
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

enum _RefreshStatus {
  success,
  invalidRefreshToken,
  networkError,
}

class _TokenRefreshResult {
  final _RefreshStatus status;
  final String? token;

  const _TokenRefreshResult({required this.status, this.token});
}

