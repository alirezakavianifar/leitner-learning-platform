import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/features/auth/data/datasources/auth_local_data_source.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};
  bool shouldThrow = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrow) throw Exception('Keystore write error');
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrow) throw Exception('Keystore read error');
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrow) throw Exception('Keystore delete error');
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService & AuthLocalDataSource Persistence Tests', () {
    late MockSecureStorage mockSecureStorage;
    late StorageService storageService;
    late AuthLocalDataSource localDataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockSecureStorage = MockSecureStorage();
      storageService = StorageServiceImpl(mockSecureStorage);
      localDataSource = AuthLocalDataSourceImpl(
        storageService: storageService,
        sharedPreferences: prefs,
      );
    });

    test('StorageService handles Keystore exceptions gracefully without crashing', () async {
      mockSecureStorage.shouldThrow = true;
      expect(() async => await storageService.writeSecure('test_key', 'value'), returnsNormally);
      final readRes = await storageService.readSecure('test_key');
      expect(readRes, isNull);
      expect(() async => await storageService.deleteSecure('test_key'), returnsNormally);
    });

    test('Tokens and User profile are saved and retrieved correctly across simulated restarts', () async {
      // 1. Cache tokens
      await localDataSource.cacheTokens(token: 'jwt_abc_123', refreshToken: 'ref_xyz_789');
      expect(await localDataSource.getCachedToken(), 'jwt_abc_123');
      expect(await localDataSource.getCachedRefreshToken(), 'ref_xyz_789');

      // 2. Cache user profile
      final now = DateTime.now();
      await localDataSource.cacheUserProfile(
        id: 'user_001',
        username: 'learner_1',
        mobileNumber: '+989120000000',
        interests: 'Languages',
        educationalField: 'Engineering',
        educationalLevel: 'BSc',
        createdAt: now,
      );

      final user = await localDataSource.getCachedUser();
      expect(user, isNotNull);
      expect(user!.id, 'user_001');
      expect(user.username, 'learner_1');
      expect(user.mobileNumber, '+989120000000');
      expect(user.interests, 'Languages');

      // 3. Clear cache
      await localDataSource.clearCache();
      expect(await localDataSource.getCachedToken(), isNull);
      expect(await localDataSource.getCachedRefreshToken(), isNull);
      expect(await localDataSource.getCachedUser(), isNull);
    });

    test('Terms acceptance is persisted properly', () async {
      expect(await localDataSource.isTermsAccepted(), false);
      await localDataSource.cacheTermsAccepted(true);
      expect(await localDataSource.isTermsAccepted(), true);
    });
  });
}
