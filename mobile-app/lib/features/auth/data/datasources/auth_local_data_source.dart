import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheTokens({required String token, required String refreshToken});
  Future<String?> getCachedToken();
  Future<String?> getCachedRefreshToken();
  Future<void> clearCache();
  Future<void> cacheTermsAccepted(bool accepted);
  Future<bool> isTermsAccepted();
  Future<void> cacheUserProfile({
    required String id,
    required String username,
    required String mobileNumber,
    String? interests,
    String? educationalField,
    String? educationalLevel,
    required DateTime createdAt,
    String? profilePictureUrl,
  });
  Future<User?> getCachedUser();
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
    await storageService.deleteSecure('active_user_id');
    await sharedPreferences.remove('terms_accepted');
    await sharedPreferences.remove('user_id');
    await sharedPreferences.remove('user_username');
    await sharedPreferences.remove('user_mobile_number');
    await sharedPreferences.remove('user_interests');
    await sharedPreferences.remove('user_educational_field');
    await sharedPreferences.remove('user_educational_level');
    await sharedPreferences.remove('user_profile_picture_url');
    await sharedPreferences.remove('user_created_at');
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
    required String id,
    required String username,
    required String mobileNumber,
    String? interests,
    String? educationalField,
    String? educationalLevel,
    required DateTime createdAt,
    String? profilePictureUrl,
  }) async {
    await storageService.writeSecure('active_user_id', id);
    await sharedPreferences.setString('user_id', id);
    await sharedPreferences.setString('user_username', username);
    await sharedPreferences.setString('user_mobile_number', mobileNumber);
    await sharedPreferences.setString('user_created_at', createdAt.toIso8601String());
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
    if (profilePictureUrl != null) {
      await sharedPreferences.setString('user_profile_picture_url', profilePictureUrl);
    } else {
      await sharedPreferences.remove('user_profile_picture_url');
    }
  }

  @override
  Future<User?> getCachedUser() async {
    final id = sharedPreferences.getString('user_id');
    final username = sharedPreferences.getString('user_username');
    final mobileNumber = sharedPreferences.getString('user_mobile_number');
    if (id == null || username == null || mobileNumber == null) {
      return null;
    }
    
    final interests = sharedPreferences.getString('user_interests');
    final educationalField = sharedPreferences.getString('user_educational_field');
    final educationalLevel = sharedPreferences.getString('user_educational_level');
    final profilePictureUrl = sharedPreferences.getString('user_profile_picture_url');
    
    final createdAtStr = sharedPreferences.getString('user_created_at');
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
    
    return User(
      id: id,
      username: username,
      mobileNumber: mobileNumber,
      interests: interests,
      educationalField: educationalField,
      educationalLevel: educationalLevel,
      profilePictureUrl: profilePictureUrl,
      createdAt: createdAt,
    );
  }

  @override
  Future<void> cacheAvatarPath(String path) async {
    await sharedPreferences.setString('user_avatar_path', path);
  }

  @override
  Future<String?> getCachedAvatarPath() async {
    final rawPath = sharedPreferences.getString('user_avatar_path');
    if (rawPath == null || rawPath.trim().isEmpty) return null;

    final file = File(rawPath);
    if (await file.exists()) {
      return rawPath;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final baseName = p.basename(rawPath);
      final migratedFile = File(p.join(appDir.path, baseName));
      if (await migratedFile.exists()) {
        await sharedPreferences.setString('user_avatar_path', migratedFile.path);
        return migratedFile.path;
      }
    } catch (_) {}

    return null;
  }
}
