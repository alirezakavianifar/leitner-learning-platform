/// Captured exception during server calls.
class ServerException implements Exception {
  final String message;
  final String? errorCode;
  const ServerException(this.message, {this.errorCode});

  @override
  String toString() => 'ServerException: $message (code: $errorCode)';
}

/// Captured exception during local storage/caching operations.
class CacheException implements Exception {
  final String message;
  const CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}

/// Captured exception for offline or direct socket errors.
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
