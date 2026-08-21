import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract storage service interface defined in the architectural design.
abstract class StorageService {
  Future<void> writeSecure(String key, String value);
  Future<String?> readSecure(String key);
  Future<void> deleteSecure(String key);
}

/// Concrete implementation utilizing the [FlutterSecureStorage] library.
class StorageServiceImpl implements StorageService {
  final FlutterSecureStorage _secureStorage;

  StorageServiceImpl(this._secureStorage);

  @override
  Future<void> writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<String?> readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }
}
