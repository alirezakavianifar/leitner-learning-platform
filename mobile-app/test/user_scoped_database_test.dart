import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:mobile_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

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
    _data.remove(key);
  }
}

class FakeAuthRemoteDataSource extends Fake implements AuthRemoteDataSource {
  @override
  Future<(String token, String refreshToken, String userStatus)> verifyOtp({
    required String mobileNumber,
    required String otpCode,
  }) async {
    return ('jwt_test_token', 'refresh_test_token', 'EXISTING_USER');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('User-Scoped Database & Multi-Account Isolation Tests', () {
    late MockSecureStorage mockSecureStorage;
    late StorageService storageService;
    late DatabaseHelper databaseHelper;
    late AuthLocalDataSource localDataSource;
    late AuthRepositoryImpl authRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockSecureStorage = MockSecureStorage();
      storageService = StorageServiceImpl(mockSecureStorage);
      databaseHelper = DatabaseHelper(storageService);
      localDataSource = AuthLocalDataSourceImpl(
        storageService: storageService,
        sharedPreferences: prefs,
      );
      authRepository = AuthRepositoryImpl(
        remoteDataSource: FakeAuthRemoteDataSource(),
        localDataSource: localDataSource,
        databaseHelper: databaseHelper,
      );
    });

    tearDown(() async {
      await databaseHelper.closeAll();
    });

    test('getLocalDatabasePath produces user-scoped database paths', () async {
      // Guest / unauthenticated
      final guestPath = await databaseHelper.getLocalDatabasePath();
      expect(guestPath.contains('app_local_guest.db'), isTrue);

      // Switch to User A
      await databaseHelper.switchUser('user_989120000000');
      final userAPath = await databaseHelper.getLocalDatabasePath();
      expect(userAPath.contains('app_local_user_989120000000.db'), isTrue);

      // Switch to User B
      await databaseHelper.switchUser('user_989350000000');
      final userBPath = await databaseHelper.getLocalDatabasePath();
      expect(userBPath.contains('app_local_user_989350000000.db'), isTrue);
      expect(userAPath, isNot(equals(userBPath)));
    });

    test('Data isolation between User A and User B in client_progress table', () async {
      // 1. User A logs in
      await databaseHelper.switchUser('user_a');
      final dbA = await databaseHelper.localDatabase;
      await dbA.delete('client_progress');

      // User A advances a card to Box 2
      await dbA.insert('client_progress', {
        'id': 'course1_1',
        'course_id': 'course1',
        'card_number': 1,
        'current_box': 2,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        'is_synced': 0,
        'has_entered_leitner': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final rowsA = await dbA.query('client_progress');
      expect(rowsA.length, 1);
      expect(rowsA.first['current_box'], 2);

      // 2. User A logs out, User B logs in
      await authRepository.logout();
      await databaseHelper.switchUser('user_b');
      final dbB = await databaseHelper.localDatabase;

      // User B database should be completely fresh and empty
      final rowsB = await dbB.query('client_progress');
      expect(rowsB.isEmpty, isTrue);

      // 3. User B logs out, User A logs back in
      await authRepository.logout();
      await databaseHelper.switchUser('user_a');
      final dbARestored = await databaseHelper.localDatabase;

      // User A data is preserved!
      final rowsARestored = await dbARestored.query('client_progress');
      expect(rowsARestored.length, 1);
      expect(rowsARestored.first['current_box'], 2);
      expect(rowsARestored.first['card_number'], 1);
    });

    test('AuthRepository verifyOtp switches database user context automatically', () async {
      final res = await authRepository.verifyOtp(
        mobileNumber: '+989121112233',
        otpCode: '12345',
      );

      expect(res.isRight, isTrue);
      expect(databaseHelper.currentUserId, 'user_989121112233');

      final dbPath = await databaseHelper.getLocalDatabasePath();
      expect(dbPath.contains('app_local_user_989121112233.db'), isTrue);
    });

    test('AuthRepository logout clears tokens, profile, and active user context', () async {
      await authRepository.verifyOtp(
        mobileNumber: '+989121112233',
        otpCode: '12345',
      );
      expect(await localDataSource.getCachedToken(), isNotNull);
      expect(databaseHelper.currentUserId, isNotNull);

      // Logout
      final logoutRes = await authRepository.logout();
      expect(logoutRes.isRight, isTrue);

      expect(await localDataSource.getCachedToken(), isNull);
      expect(await localDataSource.getCachedUser(), isNull);
      expect(databaseHelper.currentUserId, isNull);

      final guestPath = await databaseHelper.getLocalDatabasePath();
      expect(guestPath.contains('app_local_guest.db'), isTrue);
    });
  });
}
