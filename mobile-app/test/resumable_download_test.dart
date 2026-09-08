import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/features/courses/data/datasources/courses_local_data_source.dart';
import 'package:mobile_app/features/courses/data/datasources/courses_remote_data_source.dart';
import 'package:mobile_app/features/courses/data/models/course_model.dart';
import 'package:mobile_app/features/courses/data/models/course_package_model.dart';
import 'package:mobile_app/features/courses/data/repositories/courses_repository_impl.dart';

class MockRemoteDataSource implements CoursesRemoteDataSource {
  String downloadUrl = 'http://localhost:5217/courses/test-course.zip';
  String? checksum;
  int version = 1;

  @override
  Future<Map<String, dynamic>> getDownloadToken(String courseId) async {
    return {
      'download_url': downloadUrl,
      'token': 'mock-token',
      'checksum': checksum,
      'version': version,
    };
  }

  @override
  Future<List<CourseModel>> getCourses() async => [];

  @override
  Future<List<CoursePackageModel>> getPackages() async => [];

  @override
  Future<CourseModel> getCourse(String id) async {
    throw UnimplementedError();
  }
}

class MockLocalDataSource implements CoursesLocalDataSource {
  bool saveCalled = false;
  int? markedVersion;
  String? savedCourseId;
  String? savedZipPath;

  @override
  Future<void> saveDownloadedCourse({
    required String courseId,
    required String zipFilePath,
  }) async {
    saveCalled = true;
    savedCourseId = courseId;
    savedZipPath = zipFilePath;
  }

  @override
  Future<void> markCourseVersionDownloaded(String courseId, int version) async {
    markedVersion = version;
  }

  @override
  Future<void> cacheCourses(List<CourseModel> courses) async {}

  @override
  Future<List<CourseModel>> getCachedCourses() async => [];

  @override
  Future<void> cachePackages(List<CoursePackageModel> packages) async {}

  @override
  Future<List<CoursePackageModel>> getCachedPackages([List<CourseModel>? preloadedCourses]) async => [];

  @override
  Future<String> getCourseDatabasePath(String courseId) async => '';

  @override
  Future<bool> isCourseDownloaded(String courseId) async => false;
}

class FakeRangeDio extends Fake implements Dio {
  final Uint8List fullFileBytes;
  Map<String, dynamic>? lastHeaders;
  int requestCount = 0;

  FakeRangeDio(this.fullFileBytes);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    requestCount++;
    lastHeaders = options?.headers;

    final rangeHeader = options?.headers?['Range'] as String?;
    int start = 0;
    int end = fullFileBytes.length;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final spec = rangeHeader.substring(6).split('-').first.trim();
      start = int.tryParse(spec) ?? 0;
    }

    if (start >= fullFileBytes.length) {
      // 416 Range Not Satisfiable
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 416,
        headers: Headers.fromMap({
          'content-range': ['bytes */${fullFileBytes.length}'],
        }),
      );
    }

    final chunk = fullFileBytes.sublist(start, end);
    final isRange = rangeHeader != null && start > 0;

    final stream = Stream<Uint8List>.fromIterable([chunk]);
    final responseBody = ResponseBody(
      stream,
      isRange ? 206 : 200,
      headers: {
        'content-length': [chunk.length.toString()],
        if (isRange) 'content-range': ['bytes $start-${end - 1}/${fullFileBytes.length}'],
      },
    );

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: isRange ? 206 : 200,
      headers: Headers.fromMap({
        'content-length': [chunk.length.toString()],
        if (isRange) 'content-range': ['bytes $start-${end - 1}/${fullFileBytes.length}'],
      }),
      data: responseBody as T,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockRemoteDataSource remoteDataSource;
  late MockLocalDataSource localDataSource;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('resumable_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
    remoteDataSource = MockRemoteDataSource();
    localDataSource = MockLocalDataSource();
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Fresh download without existing file downloads full content and extracts', () async {
    final payload = utf8.encode('Hello World Full Package Data for Course 123');
    final expectedSha = sha256.convert(payload).toString();
    remoteDataSource.checksum = expectedSha;

    final fakeDio = FakeRangeDio(Uint8List.fromList(payload));
    final repo = CoursesRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      dio: fakeDio,
    );

    final stages = <String>[];
    final progressEvents = <int>[];

    final result = await repo.downloadCourse(
      'course-fresh',
      onProgress: (received, total) {
        progressEvents.add(received);
      },
      onStage: (stage) {
        stages.add(stage);
      },
    );

    expect(result.isRight, isTrue);
    expect(stages, contains('downloading'));
    expect(stages, contains('verifying'));
    expect(stages, contains('extracting'));
    expect(stages, contains('completed'));
    expect(localDataSource.saveCalled, isTrue);
    expect(localDataSource.markedVersion, 1);
  });

  test('Resumes partially downloaded file using HTTP 206 Range header without resetting to 0%', () async {
    final payload = utf8.encode('This is a 60-byte payload simulating a large course zip archive');
    final expectedSha = sha256.convert(payload).toString();
    remoteDataSource.checksum = expectedSha;

    // Simulate pre-existing 20 bytes on disk from an interrupted previous attempt
    const preExistingBytesCount = 20;
    final tempFilePath = p.join(tempDir.path, 'download_course-resume.zip');
    final partialFile = File(tempFilePath);
    partialFile.writeAsBytesSync(payload.sublist(0, preExistingBytesCount));

    final fakeDio = FakeRangeDio(Uint8List.fromList(payload));
    final repo = CoursesRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      dio: fakeDio,
    );

    final stages = <String>[];
    final receivedTotals = <int>[];

    final result = await repo.downloadCourse(
      'course-resume',
      onProgress: (received, total) {
        receivedTotals.add(received);
      },
      onStage: (stage) {
        stages.add(stage);
      },
    );

    expect(result.isRight, isTrue);
    // Verified that Range header requested bytes starting from 20
    expect(fakeDio.lastHeaders?['Range'], equals('bytes=$preExistingBytesCount-'));
    // Verified that progress reported the accumulated 60 bytes
    expect(receivedTotals.last, equals(payload.length));
    expect(localDataSource.saveCalled, isTrue);
  });
}
