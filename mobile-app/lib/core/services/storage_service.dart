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
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  @override
  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }
}
