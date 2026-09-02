import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:mobile_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final DatabaseHelper databaseHelper;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.databaseHelper,
  });

  @override
  Future<Either<Failure, (String captchaId, String imageBase64)>> getCaptcha() async {
    try {
      final captcha = await remoteDataSource.getCaptcha();
      return Right(captcha);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, errorCode: e.errorCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> requestOtp({
    required String mobileNumber,
    required String captchaId,
    required String captchaAnswer,
  }) async {
    try {
      final success = await remoteDataSource.requestOtp(
        mobileNumber: mobileNumber,
        captchaId: captchaId,
        captchaAnswer: captchaAnswer,
      );
      return Right(success);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, errorCode: e.errorCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, (String token, String refreshToken, String userStatus)>> verifyOtp({
    required String mobileNumber,
    required String otpCode,
  }) async {
    try {
      final result = await remoteDataSource.verifyOtp(
        mobileNumber: mobileNumber,
        otpCode: otpCode,
      );
      // Cache tokens locally
      await localDataSource.cacheTokens(token: result.$1, refreshToken: result.$2);

      // Cache minimal user profile immediately to prevent cold boot null states
      final existingUser = await localDataSource.getCachedUser();
      String activeId;
      if (existingUser == null) {
        activeId = 'user_${mobileNumber.replaceAll('+', '').replaceAll(' ', '')}';
        await localDataSource.cacheUserProfile(
          id: activeId,
          username: 'User_${mobileNumber.replaceAll('+', '').replaceAll(' ', '')}',
          mobileNumber: mobileNumber,
          createdAt: DateTime.now(),
        );
      } else {
        activeId = existingUser.id;
      }
      await databaseHelper.switchUser(activeId);

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, errorCode: e.errorCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      final profile = await remoteDataSource.getProfile();
      await databaseHelper.switchUser(profile.id);
      await localDataSource.cacheUserProfile(
        id: profile.id,
        username: profile.username,
        mobileNumber: profile.mobileNumber,
        interests: profile.interests,
        educationalField: profile.educationalField,
        educationalLevel: profile.educationalLevel,
        createdAt: profile.createdAt,
        profilePictureUrl: profile.profilePictureUrl,
      );
      return Right(profile);
    } on ServerException catch (e) {
      if (e.errorCode != 'UNAUTHORIZED' && e.errorCode != 'INVALID_TOKEN' && e.errorCode != 'SESSION_EXPIRED') {
        final cached = await localDataSource.getCachedUser();
        if (cached != null) {
          await databaseHelper.switchUser(cached.id);
          return Right(cached);
        }
      }
      return Left(ServerFailure(e.message, errorCode: e.errorCode));
    } catch (e) {
      final cached = await localDataSource.getCachedUser();
      if (cached != null) {
        await databaseHelper.switchUser(cached.id);
        return Right(cached);
      }
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile({
    required String username,
    String? interests,
    String? educationalField,
    String? educationalLevel,
    File? profilePicture,
  }) async {
    try {
      String? remoteAvatarUrl;
      if (profilePicture != null) {
        try {
          remoteAvatarUrl = await remoteDataSource.uploadAvatar(profilePicture);
        } catch (_) {
          // Continue updating other profile fields even if avatar upload fails (e.g. offline)
        }

        try {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'profile_avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(profilePicture.path)}';
          final savedFile = await profilePicture.copy(p.join(appDir.path, fileName));
          await localDataSource.cacheAvatarPath(savedFile.path);
        } catch (_) {}
      }

      final profile = await remoteDataSource.updateProfile(
        username: username,
        interests: interests,
        educationalField: educationalField,
        educationalLevel: educationalLevel,
      );

      final finalAvatarUrl = remoteAvatarUrl ?? profile.profilePictureUrl;
      final updatedProfile = User(
        id: profile.id,
        username: profile.username,
        mobileNumber: profile.mobileNumber,
        interests: profile.interests,
        educationalField: profile.educationalField,
        educationalLevel: profile.educationalLevel,
        createdAt: profile.createdAt,
        profilePictureUrl: finalAvatarUrl,
      );

      await databaseHelper.switchUser(updatedProfile.id);
      await localDataSource.cacheUserProfile(
        id: updatedProfile.id,
        username: updatedProfile.username,
        mobileNumber: updatedProfile.mobileNumber,
        interests: updatedProfile.interests,
        educationalField: updatedProfile.educationalField,
        educationalLevel: updatedProfile.educationalLevel,
        createdAt: updatedProfile.createdAt,
        profilePictureUrl: updatedProfile.profilePictureUrl,
      );

      return Right(updatedProfile);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, errorCode: e.errorCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> checkTermsAccepted() async {
    try {
      final accepted = await localDataSource.isTermsAccepted();
      return Right(accepted);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> acceptTerms() async {
    try {
      await localDataSource.cacheTermsAccepted(true);
      return const Right(true);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> logout() async {
    try {
      await localDataSource.clearCache();
      await databaseHelper.switchUser(null);
      await databaseHelper.closeAll();
      return const Right(true);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
