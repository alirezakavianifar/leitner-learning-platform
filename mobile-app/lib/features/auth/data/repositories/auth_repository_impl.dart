import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
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
          return Right(cached);
        }
      }
      return Left(ServerFailure(e.message, errorCode: e.errorCode));
    } catch (e) {
      final cached = await localDataSource.getCachedUser();
      if (cached != null) {
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
      final profile = await remoteDataSource.updateProfile(
        username: username,
        interests: interests,
        educationalField: educationalField,
        educationalLevel: educationalLevel,
      );

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

      if (profilePicture != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(profilePicture.path)}';
        final savedFile = await profilePicture.copy(p.join(appDir.path, fileName));
        await localDataSource.cacheAvatarPath(savedFile.path);
      }

      return Right(profile);
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
      return const Right(true);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
