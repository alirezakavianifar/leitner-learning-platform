import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/features/courses/data/models/course_model.dart';

abstract class CoursesLocalDataSource {
  Future<void> cacheCourses(List<CourseModel> courses);
  Future<List<CourseModel>> getCachedCourses();
  Future<bool> isCourseDownloaded(String courseId);
  Future<String> getCourseDatabasePath(String courseId);
  Future<void> saveDownloadedCourse({
    required String courseId,
    required String zipFilePath,
  });
}

class CoursesLocalDataSourceImpl implements CoursesLocalDataSource {
  final DatabaseHelper databaseHelper;

  CoursesLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> cacheCourses(List<CourseModel> courses) async {
    final db = await databaseHelper.localDatabase;
    await db.transaction((txn) async {
      // Clear existing cache
      await txn.delete('courses_cache');
      
      // Insert new cache items
      for (final course in courses) {
        await txn.insert(
          'courses_cache',
          course.toCacheMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<CourseModel>> getCachedCourses() async {
    final db = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await db.query('courses_cache', orderBy: 'title');
    
    final List<CourseModel> list = [];
    for (final map in maps) {
      final courseId = map['id'] as String;
      final isDownloaded = await isCourseDownloaded(courseId);
      final dbPath = isDownloaded ? await getCourseDatabasePath(courseId) : null;
      
      list.add(
        CourseModel.fromCacheMap(
          map,
          isDownloaded: isDownloaded,
          localDbPath: dbPath,
        ),
      );
    }
    return list;
  }

  @override
  Future<bool> isCourseDownloaded(String courseId) async {
    final dbPath = await getCourseDatabasePath(courseId);
    return File(dbPath).existsSync();
  }

  @override
  Future<String> getCourseDatabasePath(String courseId) async {
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'courses', courseId, 'course.db');
  }

  @override
  Future<void> saveDownloadedCourse({
    required String courseId,
    required String zipFilePath,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final courseDir = p.join(docDir.path, 'courses', courseId);
    
    // Create course folder structure if not exists
    final targetDir = Directory(courseDir);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final tempExtractDir = p.join(docDir.path, 'temp_extract_$courseId');
    final tempDir = Directory(tempExtractDir);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    tempDir.createSync(recursive: true);

    // 1. Unpack ZIP archive to temporary directory
    final zipFile = File(zipFilePath);
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(p.join(tempExtractDir, filename));
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(data);
      }
    }

    final tempDbPath = p.join(tempExtractDir, 'course.db');
    if (!File(tempDbPath).existsSync()) {
      throw Exception('Database file course.db is missing in the package.');
    }

    // 2. Perform Schema Migration & Progress Synchronization in local db
    final courseDb = await databaseHelper.openCourseDatabase(tempDbPath);
    
    // Get all valid card numbers from the new course database
    final List<Map<String, dynamic>> cardRows = await courseDb.query(
      'cards',
      columns: ['card_number'],
    );
    final newCardNumbers = cardRows.map((row) => row['card_number'] as int).toSet();
    await courseDb.close();

    final localDb = await databaseHelper.localDatabase;

    // Get existing local progress for this course
    final List<Map<String, dynamic>> progressRows = await localDb.query(
      'client_progress',
      columns: ['card_number'],
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    final existingCardNumbers = progressRows.map((row) => row['card_number'] as int).toSet();

    // A. Insert defaults for new card numbers added
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cardsToInsert = newCardNumbers.difference(existingCardNumbers);
    
    await localDb.transaction((txn) async {
      for (final cardNum in cardsToInsert) {
        final compositeId = '${courseId}_$cardNum';
        await txn.insert(
          'client_progress',
          {
            'id': compositeId,
            'course_id': courseId,
            'card_number': cardNum,
            'current_box': 1,
            'last_reviewed_at': null,
            'next_review_due': nowIso,
            'is_synced': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // B. Remove progress records for deleted card numbers
      final cardsToDelete = existingCardNumbers.difference(newCardNumbers);
      for (final cardNum in cardsToDelete) {
        final compositeId = '${courseId}_$cardNum';
        await txn.delete(
          'client_progress',
          where: 'id = ?',
          whereArgs: [compositeId],
        );
        await txn.delete(
          'favorites',
          where: 'course_id = ? AND card_number = ?',
          whereArgs: [courseId, cardNum],
        );
      }
    });

    // 3. Swap the old database/assets with the new ones
    final targetDbFile = File(p.join(courseDir, 'course.db'));
    if (targetDbFile.existsSync()) {
      targetDbFile.deleteSync();
    }
    File(tempDbPath).copySync(targetDbFile.path);

    // Swap images/audio subdirectories
    final tempImagesDir = Directory(p.join(tempExtractDir, 'images'));
    final targetImagesDir = Directory(p.join(courseDir, 'images'));
    if (tempImagesDir.existsSync()) {
      if (targetImagesDir.existsSync()) {
        targetImagesDir.deleteSync(recursive: true);
      }
      tempImagesDir.renameSync(targetImagesDir.path);
    }

    final tempAudioDir = Directory(p.join(tempExtractDir, 'audio'));
    final targetAudioDir = Directory(p.join(courseDir, 'audio'));
    if (tempAudioDir.existsSync()) {
      if (targetAudioDir.existsSync()) {
        targetAudioDir.deleteSync(recursive: true);
      }
      tempAudioDir.renameSync(targetAudioDir.path);
    }

    // Clean up temporary files
    try {
      tempDir.deleteSync(recursive: true);
      zipFile.deleteSync();
    } catch (_) {}
  }
}
