import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/data/datasources/courses_local_data_source.dart';
import 'package:mobile_app/features/courses/data/datasources/courses_remote_data_source.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  final CoursesRemoteDataSource remoteDataSource;
  final CoursesLocalDataSource localDataSource;
  final Dio dio; // Direct dio instance for downloading files

  CoursesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.dio,
  });

  @override
  Future<Either<Failure, (List<Course> courses, bool isOffline)>> getCourses() async {
    try {
      // 1. Fetch remote list
      final remoteCourses = await remoteDataSource.getCourses();
      
      if (kIsWeb) {
        return Right((remoteCourses, false));
      }

      // 2. Cache locally
      await localDataSource.cacheCourses(remoteCourses);
      
      // 3. Return combined/cached list (incorporates client-side downloaded/dbPath flags)
      final cachedCourses = await localDataSource.getCachedCourses();
      return Right((cachedCourses, false));
    } catch (e) {
      if (kIsWeb) {
        return Left(NetworkFailure('Failed to load courses: ${e.toString()}'));
      }
      // Offline fallback: load cached courses if database/network fails
      try {
        final cachedCourses = await localDataSource.getCachedCourses();
        if (cachedCourses.isNotEmpty) {
          final offlineCourses = cachedCourses.map((c) => c.copyWith()).toList();
          return Right((offlineCourses, true));
        }
        return Left(NetworkFailure('No internet connection and no cached courses found.'));
      } catch (cacheErr) {
        return Left(CacheFailure('Failed to load local courses cache: ${cacheErr.toString()}'));
      }
    }
  }

  @override
  Future<Either<Failure, void>> downloadCourse(
    String courseId, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      return Left(ServerFailure('Offline course downloads are available on mobile and desktop apps.'));
    }
    try {
      // 1. Fetch download token and url from backend
      final tokenInfo = await remoteDataSource.getDownloadToken(courseId);
      var downloadUrl = tokenInfo['download_url'] as String;
      final expectedChecksum = tokenInfo['checksum'] as String?;

      if (!kIsWeb && Platform.isAndroid && downloadUrl.contains('localhost')) {
        downloadUrl = downloadUrl.replaceAll('localhost', '10.0.2.2');
      } else if (!kIsWeb && Platform.isWindows && downloadUrl.contains('10.0.2.2')) {
        downloadUrl = downloadUrl.replaceAll('10.0.2.2', 'localhost');
      }

      // 2. Download package ZIP file to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'download_$courseId.zip');
      
      final response = await dio.download(
        downloadUrl,
        tempZipPath,
        onReceiveProgress: onProgress,
        options: Options(
          headers: {
            'Accept': '*/*',
            'Accept-Encoding': 'identity',
          },
        ),
      );


      if (response.statusCode != 200) {
        return Left(ServerFailure('Failed to download course archive package.'));
      }

      // 3. Verify checksum (if provided)
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final isVerified = await _verifyChecksum(tempZipPath, expectedChecksum);
        if (!isVerified) {
          try {
            File(tempZipPath).deleteSync();
          } catch (_) {}
          return Left(ServerFailure('Course download verification failed. Checksum mismatch.', errorCode: 'CHECKSUM_MISMATCH'));
        }
      }

      // 4. Save and extract locally (merges progress tables automatically)
      await localDataSource.saveDownloadedCourse(
        courseId: courseId,
        zipFilePath: tempZipPath,
      );

      return const Right(null);
    } on DioException catch (dioErr) {
      final message = dioErr.response?.data?['message'] ?? dioErr.message;
      final errorCode = dioErr.response?.data?['error_code'];
      return Left(ServerFailure(message, errorCode: errorCode));
    } catch (e) {
      return Left(CacheFailure('Failed to process and save course package: ${e.toString()}'));
    }
  }

  Future<bool> _verifyChecksum(String filePath, String expectedChecksum) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    
    final fileBytes = await file.readAsBytes();
    final hashHex = sha256.convert(fileBytes).toString().toLowerCase();
    
    var cleanExpected = expectedChecksum.toLowerCase();
    if (cleanExpected.startsWith('sha256-')) {
      cleanExpected = cleanExpected.substring(7);
    }
    return hashHex == cleanExpected;
  }
}
