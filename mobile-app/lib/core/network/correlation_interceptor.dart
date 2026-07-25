import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../diagnostics/app_logger.dart';

class CorrelationInterceptor extends Interceptor {
  final _uuid = const Uuid();
  static const String correlationIdHeaderKey = 'X-Correlation-ID';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Generate Correlation ID if not present
    if (!options.headers.containsKey(correlationIdHeaderKey) || options.headers[correlationIdHeaderKey] == null) {
      final correlationId = _uuid.v4();
      options.headers[correlationIdHeaderKey] = correlationId;
    }
    
    final correlationId = options.headers[correlationIdHeaderKey];
    AppLogger().info('API Request: ${options.method} ${options.uri} | CorrelationId: $correlationId');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final correlationId = response.requestOptions.headers[correlationIdHeaderKey];
    AppLogger().info('API Response: ${response.statusCode} ${response.requestOptions.uri} | CorrelationId: $correlationId');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final correlationId = err.requestOptions.headers[correlationIdHeaderKey];
    
    // Extract server-provided correlation ID or fallback to client-side correlation ID
    String? serverCorrelationId;
    if (err.response?.data is Map<String, dynamic>) {
      final data = err.response!.data as Map<String, dynamic>;
      if (data.containsKey('correlation_id')) {
        serverCorrelationId = data['correlation_id']?.toString();
      }
    }
    
    final activeCorrelationId = serverCorrelationId ?? correlationId ?? 'unknown';
    
    AppLogger().error(
      'API Error: ${err.message} | Path: ${err.requestOptions.uri} | CorrelationId: $activeCorrelationId',
      err.error,
      err.stackTrace,
    );
    
    super.onError(err, handler);
  }
}
