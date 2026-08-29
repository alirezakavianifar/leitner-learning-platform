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
import 'package:mobile_app/features/courses/data/models/course_model.dart';
import 'package:mobile_app/features/courses/data/models/course_package_model.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  final CoursesRemoteDataSource remoteDataSource;
  final CoursesLocalDataSource localDataSource;
  final Dio dio; // Direct dio instance for downloading files
  final EventBus? eventBus;

  CoursesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.dio,
    this.eventBus,
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
  Future<Either<Failure, (List<CoursePackage> packages, bool isOffline)>> getPackages() async {
    try {
      final remotePackages = await remoteDataSource.getPackages();
      if (kIsWeb) {
        return Right((remotePackages, false));
      }

      await localDataSource.cachePackages(remotePackages);
      final cachedPackages = await localDataSource.getCachedPackages();
      return Right((cachedPackages, false));
    } catch (e) {
      if (kIsWeb) {
        return Left(NetworkFailure('Failed to load packages: ${e.toString()}'));
      }
      try {
        final cachedPackages = await localDataSource.getCachedPackages();
        if (cachedPackages.isNotEmpty) {
          return Right((cachedPackages, true));
        }
        return Right((const [], true));
      } catch (cacheErr) {
        return Left(CacheFailure('Failed to load local packages cache: ${cacheErr.toString()}'));
      }
    }
  }

  @override
  Future<Either<Failure, (List<Course> courses, List<CoursePackage> packages, bool isOffline)>> getCoursesAndPackages() async {
    List<CourseModel>? remoteCourses;
    List<CoursePackageModel>? remotePackages;
    bool fetchedFromRemote = false;

    try {
      // 1. Fetch remote courses and packages concurrently in parallel
      final results = await Future.wait([
        remoteDataSource.getCourses().then<dynamic>((res) => res).catchError((_) => null),
        remoteDataSource.getPackages().then<dynamic>((res) => res).catchError((_) => null),
      ]);

      if (results[0] is List<CourseModel>) {
        remoteCourses = results[0] as List<CourseModel>;
        remotePackages = results[1] is List<CoursePackageModel> ? results[1] as List<CoursePackageModel> : [];
        fetchedFromRemote = true;
      }
    } catch (_) {
      fetchedFromRemote = false;
    }

    if (fetchedFromRemote && remoteCourses != null) {
      if (kIsWeb) {
        return Right((
          remoteCourses,
          remotePackages ?? [],
          false,
        ));
      }

      // 2. Cache locally asynchronously
      try {
        await localDataSource.cacheCourses(remoteCourses);
        if (remotePackages != null && remotePackages.isNotEmpty) {
          await localDataSource.cachePackages(remotePackages);
        }
      } catch (_) {}

      try {
        final cachedCourses = await localDataSource.getCachedCourses();
        final cachedPackages = await localDataSource.getCachedPackages(cachedCourses);
        return Right((
          cachedCourses.isNotEmpty ? cachedCourses : remoteCourses,
          cachedPackages.isNotEmpty ? cachedPackages : (remotePackages ?? []),
          false,
        ));
      } catch (_) {
        return Right((remoteCourses, remotePackages ?? [], false));
      }
    } else {
      // Offline fallback: load from local cache
      if (kIsWeb) {
        return Left(NetworkFailure('Failed to load catalog from server.'));
      }
      try {
        final cachedCourses = await localDataSource.getCachedCourses();
        final cachedPackages = await localDataSource.getCachedPackages(cachedCourses);

        if (cachedCourses.isNotEmpty || cachedPackages.isNotEmpty) {
          return Right((cachedCourses, cachedPackages, true));
        }
        return Left(NetworkFailure('No internet connection and no cached courses or packages found.'));
      } catch (cacheErr) {
        return Left(CacheFailure('Failed to load offline catalog: ${cacheErr.toString()}'));
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

      // Always clear any stale partially-downloaded file from prior aborted attempts
      try {
        final existingFile = File(tempZipPath);
        if (existingFile.existsSync()) {
          existingFile.deleteSync();
        }
      } catch (_) {}

      // Retry up to 3 times on transient network drops or socket terminations
      Response? response;
      const maxRetries = 3;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          response = await dio.download(
            downloadUrl,
            tempZipPath,
            onReceiveProgress: onProgress,
            options: Options(
              headers: {
                'Accept': '*/*',
                'Accept-Encoding': 'identity',
              },
              receiveTimeout: const Duration(seconds: 180),
            ),
          );

          if (response.statusCode == 200) {
            final file = File(tempZipPath);
            final actualLength = file.existsSync() ? file.lengthSync() : 0;
            final expectedLength = _extractContentLength(response.headers.map);

            // If the server provided Content-Length and file is smaller, stream cut short
            if (expectedLength != null && actualLength < expectedLength) {
              if (attempt < maxRetries) {
                try { file.deleteSync(); } catch (_) {}
                await Future.delayed(Duration(seconds: attempt * 2));
                continue;
              }
            }
            break;
          }
        } catch (e) {
          if (attempt == maxRetries) {
            rethrow;
          }
          try {
            final f = File(tempZipPath);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      if (response == null || response.statusCode != 200) {
        return Left(ServerFailure('Failed to download course archive package.'));
      }

      // 3. Verify the file actually arrived intact before trusting it.
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
      if (expectedChecksum != null && expectedChecksum.trim().isNotEmpty && expectedChecksum.trim().toLowerCase() != 'null') {
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
        eventBus?.fire(CourseDownloaded(courseId: courseId));
      } catch (e) {
        // The package failed to extract/process. Clean up so a retry starts from a clean slate.
        try {
          File(tempZipPath).deleteSync();
        } catch (_) {}
        return Left(CacheFailure(
          'Failed to process course package: ${e.toString().replaceFirst("Exception: ", "")}',
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

    var cleanExpected = expectedChecksum.trim().toLowerCase();
    if (cleanExpected.startsWith('sha256-')) {
      cleanExpected = cleanExpected.substring(7);
    } else if (cleanExpected.startsWith('sha256:')) {
      cleanExpected = cleanExpected.substring(7);
    } else if (cleanExpected.startsWith('sha-256:')) {
      cleanExpected = cleanExpected.substring(8);
    }
    if (cleanExpected.isEmpty || cleanExpected == 'null') return true;

    try {
      final digest = await file.openRead().transform(sha256).first;
      final hashHex = digest.toString().toLowerCase();
      return hashHex == cleanExpected;
    } catch (_) {
      return false;
    }
  }
}
