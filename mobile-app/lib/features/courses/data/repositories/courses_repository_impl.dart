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
    // Declared outside the try block so cleanup in the catch clauses below
    // can still reach the partially-downloaded file, if any.
    String? tempZipPath;
    try {
      // 1. Fetch download token and url from backend
      final tokenInfo = await remoteDataSource.getDownloadToken(courseId);
      var downloadUrl = tokenInfo['download_url'] as String;
      final expectedChecksum = tokenInfo['checksum'] as String?;
      final downloadedVersion = tokenInfo['version'] as int?;

      if (!kIsWeb && Platform.isAndroid && downloadUrl.contains('localhost')) {
        downloadUrl = downloadUrl.replaceAll('localhost', '10.0.2.2');
      } else if (!kIsWeb && Platform.isWindows && downloadUrl.contains('10.0.2.2')) {
        downloadUrl = downloadUrl.replaceAll('10.0.2.2', 'localhost');
      }

      // 2. Download package ZIP file to temp directory
      final tempDir = await getTemporaryDirectory();
      tempZipPath = p.join(tempDir.path, 'download_$courseId.zip');

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

      // 3. Verify the file actually arrived intact before trusting it.
      // A flaky mobile connection can drop mid-transfer while dio still
      // reports completion, so we cross-check the on-disk size against the
      // server-reported Content-Length whenever it is available.
      final expectedLength = _extractContentLength(response.headers.map);
      final actualLength = File(tempZipPath).existsSync() ? File(tempZipPath).lengthSync() : 0;
      if (actualLength == 0 || (expectedLength != null && actualLength != expectedLength)) {
        try {
          File(tempZipPath).deleteSync();
        } catch (_) {}
        return Left(ServerFailure(
          'The course download was interrupted before it finished. Please check your connection and try again.',
          errorCode: 'INCOMPLETE_DOWNLOAD',
        ));
      }

      // 4. Verify checksum (if provided)
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final isVerified = await _verifyChecksum(tempZipPath, expectedChecksum);
        if (!isVerified) {
          try {
            File(tempZipPath).deleteSync();
          } catch (_) {}
          return Left(ServerFailure('Course download verification failed. Checksum mismatch.', errorCode: 'CHECKSUM_MISMATCH'));
        }
      }

      // 5. Save and extract locally (merges progress tables automatically)
      try {
        await localDataSource.saveDownloadedCourse(
          courseId: courseId,
          zipFilePath: tempZipPath,
        );
        if (downloadedVersion != null) {
          await localDataSource.markCourseVersionDownloaded(courseId, downloadedVersion);
        }
      } catch (e) {
        // The package failed to extract/process - most likely a corrupted or
        // incomplete download. Clean up so a retry starts from a clean slate.
        try {
          File(tempZipPath).deleteSync();
        } catch (_) {}
        return Left(CacheFailure(
          'The downloaded course package could not be processed (it may have been corrupted in transit). Please try downloading again.',
        ));
      }

      return const Right(null);
    } on DioException catch (dioErr) {
      if (tempZipPath != null) {
        try {
          File(tempZipPath).deleteSync();
        } catch (_) {}
      }
      final message = dioErr.response?.data?['message'] ?? dioErr.message;
      final errorCode = dioErr.response?.data?['error_code'];
      return Left(ServerFailure(message, errorCode: errorCode));
    } catch (e) {
      return Left(CacheFailure('Failed to process and save course package: ${e.toString()}'));
    }
  }

  /// Reads the `content-length` response header (case-insensitive), if present.
  int? _extractContentLength(Map<String, List<String>> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-length' && entry.value.isNotEmpty) {
        return int.tryParse(entry.value.first);
      }
    }
    return null;
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
