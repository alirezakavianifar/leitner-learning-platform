import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/features/courses/data/datasources/courses_local_data_source.dart';

class MockStorageService extends Fake implements StorageService {
  final Map<String, String> _secure = {};

  @override
  Future<String?> readSecure(String key) async => _secure[key];

  @override
  Future<void> writeSecure(String key, String value) async => _secure[key] = value;

  @override
  Future<void> deleteSecure(String key) async => _secure.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempTestDir;
  late DatabaseHelper dbHelper;
  late CoursesLocalDataSource localDataSource;

  setUp(() async {
    tempTestDir = Directory.systemTemp.createTempSync('course_extraction_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempTestDir.path;
      },
    );

    final storage = MockStorageService();
    dbHelper = DatabaseHelper(storage);
    localDataSource = CoursesLocalDataSourceImpl(databaseHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.closeAll();
    try {
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Extracts standard package with course.db at root successfully', () async {
    const courseId = 'standard-course-123';
    
    // 1. Create a dummy standard SQLite course.db
    final pkgDir = Directory(p.join(tempTestDir.path, 'pkg_std'));
    pkgDir.createSync(recursive: true);
    final dbFile = File(p.join(pkgDir.path, 'course.db'));
    final db = await openDatabase(dbFile.path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE cards (
          id TEXT PRIMARY KEY,
          course_id TEXT NOT NULL,
          card_number INTEGER NOT NULL,
          question_text TEXT NOT NULL,
          answer_text TEXT NOT NULL,
          image_name TEXT,
          audio_name TEXT
        );
      ''');
      await db.insert('cards', {
        'id': 'c1',
        'course_id': courseId,
        'card_number': 1,
        'question_text': 'Q1',
        'answer_text': 'A1',
        'audio_name': 'test.mp3',
      });
    });
    await db.close();

    // Create dummy audio
    final audDir = Directory(p.join(pkgDir.path, 'audio'))..createSync(recursive: true);
    File(p.join(audDir.path, 'test.mp3')).writeAsStringSync('dummy audio');

    // Create zip
    final zipPath = p.join(tempTestDir.path, 'std.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(pkgDir, includeDirName: false);
    encoder.close();

    // 2. Run saveDownloadedCourse
    await localDataSource.saveDownloadedCourse(courseId: courseId, zipFilePath: zipPath);

    // 3. Verify
    final courseDbPath = await localDataSource.getCourseDatabasePath(courseId);
    expect(File(courseDbPath).existsSync(), isTrue);

    final audioPath = p.join(tempTestDir.path, 'courses', courseId, 'audio', 'test.mp3');
    expect(File(audioPath).existsSync(), isTrue);

    final localDb = await dbHelper.localDatabase;
    final progress = await localDb.query('client_progress', where: 'course_id = ?', whereArgs: [courseId]);
    expect(progress.length, equals(1));
    expect(progress.first['card_number'], equals(1));
  });

  test('Extracts legacy package with nested directory and non-standard columns', () async {
    const courseId = '50400000-0000-0000-0000-000000000504';
    
    // 1. Create a dummy legacy nested package structure: 504/504.db and 504/pronunciation/abandon.mp3
    final pkgDir = Directory(p.join(tempTestDir.path, 'pkg_legacy', '504'));
    pkgDir.createSync(recursive: true);
    final dbFile = File(p.join(pkgDir.path, '504.db'));
    final db = await openDatabase(dbFile.path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE cards (
          number INTEGER PRIMARY KEY,
          questions TEXT NOT NULL,
          answer TEXT NOT NULL,
          "front voice" TEXT,
          "front image" TEXT
        );
      ''');
      await db.rawInsert(
        'INSERT INTO cards (number, questions, answer, "front voice") VALUES (?, ?, ?, ?)',
        [1, 'abandon', 'to leave completely', 'abandon.mp3'],
      );
      await db.rawInsert(
        'INSERT INTO cards (number, questions, answer, "front voice") VALUES (?, ?, ?, ?)',
        [2, 'abide', 'to tolerate', 'abide.mp3'],
      );
    });
    await db.close();

    final pronunDir = Directory(p.join(pkgDir.path, 'pronunciation'))..createSync(recursive: true);
    File(p.join(pronunDir.path, 'abandon.mp3')).writeAsStringSync('audio 1');
    File(p.join(pronunDir.path, 'abide.mp3')).writeAsStringSync('audio 2');

    // Create zip with root folder '504/'
    final zipPath = p.join(tempTestDir.path, 'legacy_504.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(Directory(p.join(tempTestDir.path, 'pkg_legacy')), includeDirName: false);
    encoder.close();

    // 2. Run saveDownloadedCourse
    await localDataSource.saveDownloadedCourse(courseId: courseId, zipFilePath: zipPath);

    // 3. Verify
    final courseDbPath = await localDataSource.getCourseDatabasePath(courseId);
    expect(File(courseDbPath).existsSync(), isTrue);

    // Verify schema is normalized to standard cards table
    final courseDb = await dbHelper.openCourseDatabase(courseDbPath);
    final cards = await courseDb.query('cards', orderBy: 'card_number');
    expect(cards.length, equals(2));
    expect(cards[0]['card_number'], equals(1));
    expect(cards[0]['question_text'], equals('abandon'));
    expect(cards[0]['answer_text'], equals('to leave completely'));
    expect(cards[0]['audio_name'], equals('abandon.mp3'));
    await courseDb.close();

    // Verify audio files flattened into courses/{courseId}/audio
    expect(File(p.join(tempTestDir.path, 'courses', courseId, 'audio', 'abandon.mp3')).existsSync(), isTrue);
    expect(File(p.join(tempTestDir.path, 'courses', courseId, 'audio', 'abide.mp3')).existsSync(), isTrue);

    // Verify client progress populated
    final localDb = await dbHelper.localDatabase;
    final progress = await localDb.query('client_progress', where: 'course_id = ?', whereArgs: [courseId], orderBy: 'card_number');
    expect(progress.length, equals(2));
    expect(progress[0]['card_number'], equals(1));
    expect(progress[1]['card_number'], equals(2));
  });
}
