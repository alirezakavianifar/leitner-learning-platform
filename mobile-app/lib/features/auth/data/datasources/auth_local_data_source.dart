import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/services/storage_service.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheTokens({required String token, required String refreshToken});
  Future<String?> getCachedToken();
  Future<String?> getCachedRefreshToken();
  Future<void> clearCache();
  Future<void> cacheTermsAccepted(bool accepted);
  Future<bool> isTermsAccepted();
  Future<void> cacheUserProfile({
    required String username,
    String? interests,
    String? educationalField,
    String? educationalLevel,
  });
  Future<void> cacheAvatarPath(String path);
  Future<String?> getCachedAvatarPath();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final StorageService storageService;
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({
    required this.storageService,
    required this.sharedPreferences,
  });

  @override
  Future<void> cacheTokens({required String token, required String refreshToken}) async {
    await storageService.writeSecure('jwt_token', token);
    await storageService.writeSecure('refresh_token', refreshToken);
  }

  @override
  Future<String?> getCachedToken() {
    return storageService.readSecure('jwt_token');
  }

  @override
  Future<String?> getCachedRefreshToken() {
    return storageService.readSecure('refresh_token');
  }

  @override
  Future<void> clearCache() async {
    await storageService.deleteSecure('jwt_token');
    await storageService.deleteSecure('refresh_token');
    await sharedPreferences.remove('terms_accepted');
    await sharedPreferences.remove('user_username');
    await sharedPreferences.remove('user_interests');
    await sharedPreferences.remove('user_educational_field');
    await sharedPreferences.remove('user_educational_level');
    await sharedPreferences.remove('user_avatar_path');
  }

  @override
  Future<void> cacheTermsAccepted(bool accepted) async {
    await sharedPreferences.setBool('terms_accepted', accepted);
  }

  @override
  Future<bool> isTermsAccepted() async {
    return sharedPreferences.getBool('terms_accepted') ?? false;
  }

  @override
  Future<void> cacheUserProfile({
    required String username,
    String? interests,
    String? educationalField,
    String? educationalLevel,
  }) async {
    await sharedPreferences.setString('user_username', username);
    if (interests != null) {
      await sharedPreferences.setString('user_interests', interests);
    } else {
      await sharedPreferences.remove('user_interests');
    }
    if (educationalField != null) {
      await sharedPreferences.setString('user_educational_field', educationalField);
    } else {
      await sharedPreferences.remove('user_educational_field');
    }
    if (educationalLevel != null) {
      await sharedPreferences.setString('user_educational_level', educationalLevel);
    } else {
      await sharedPreferences.remove('user_educational_level');
    }
  }

  @override
  Future<void> cacheAvatarPath(String path) async {
    await sharedPreferences.setString('user_avatar_path', path);
  }

  @override
  Future<String?> getCachedAvatarPath() async {
    return sharedPreferences.getString('user_avatar_path');
  }
}
