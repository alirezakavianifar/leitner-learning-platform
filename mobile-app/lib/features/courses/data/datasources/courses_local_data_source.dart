import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/features/courses/data/models/course_model.dart';
import 'package:mobile_app/features/courses/data/models/course_package_model.dart';

abstract class CoursesLocalDataSource {
  Future<void> cacheCourses(List<CourseModel> courses);
  Future<List<CourseModel>> getCachedCourses();
  Future<void> cachePackages(List<CoursePackageModel> packages);
  Future<List<CoursePackageModel>> getCachedPackages([List<CourseModel>? preloadedCourses]);
  Future<bool> isCourseDownloaded(String courseId);
  Future<String> getCourseDatabasePath(String courseId);
  Future<void> saveDownloadedCourse({
    required String courseId,
    required String zipFilePath,
  });
  /// Records which content version is now on-disk for [courseId], so future
  /// catalog refreshes can detect when the server has a newer version.
  Future<void> markCourseVersionDownloaded(String courseId, int version);
}

class CoursesLocalDataSourceImpl implements CoursesLocalDataSource {
  final DatabaseHelper databaseHelper;
  String? _cachedCoursesBasePath;

  CoursesLocalDataSourceImpl({required this.databaseHelper});

  Future<String> _getBaseCoursesDirectory() async {
    if (_cachedCoursesBasePath != null) {
      return _cachedCoursesBasePath!;
    }
    final docDir = await getApplicationDocumentsDirectory();
    _cachedCoursesBasePath = p.join(docDir.path, 'courses');
    return _cachedCoursesBasePath!;
  }

  @override
  Future<void> cacheCourses(List<CourseModel> courses) async {
    final db = await databaseHelper.localDatabase;
    await db.transaction((txn) async {
      // Preserve locally-known downloaded versions - the server response never
      // carries this client-owned state, and a plain REPLACE would wipe it.
      final existingRows = await txn.query('courses_cache', columns: ['id', 'downloaded_version']);
      final downloadedVersions = <String, int>{};
      for (final row in existingRows) {
        final version = row['downloaded_version'] as int?;
        if (version != null) {
          downloadedVersions[row['id'] as String] = version;
        }
      }

      // Clear existing cache
      await txn.delete('courses_cache');

      // Insert new cache items
      for (final course in courses) {
        await txn.insert(
          'courses_cache',
          course.toCacheMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final preservedVersion = downloadedVersions[course.id];
        if (preservedVersion != null) {
          await txn.update(
            'courses_cache',
            {'downloaded_version': preservedVersion},
            where: 'id = ?',
            whereArgs: [course.id],
          );
        }
      }
    });
  }

  @override
  Future<List<CourseModel>> getCachedCourses() async {
    final db = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await db.query('courses_cache', orderBy: 'title');
    if (maps.isEmpty) return [];

    final baseDir = await _getBaseCoursesDirectory();
    final List<CourseModel> list = [];

    for (final map in maps) {
      final courseId = map['id'] as String;
      final dbPath = p.join(baseDir, courseId, 'course.db');
      final isDownloaded = File(dbPath).existsSync();
      
      list.add(
        CourseModel.fromCacheMap(
          map,
          isDownloaded: isDownloaded,
          localDbPath: isDownloaded ? dbPath : null,
        ),
      );
    }
    return list;
  }

  @override
  Future<void> cachePackages(List<CoursePackageModel> packages) async {
    final db = await databaseHelper.localDatabase;
    await db.transaction((txn) async {
      await txn.delete('packages_cache');
      await txn.delete('package_courses_cache');

      for (final pkg in packages) {
        await txn.insert(
          'packages_cache',
          pkg.toCacheMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        int order = 0;
        for (final c in pkg.courses) {
          await txn.insert(
            'package_courses_cache',
            {
              'package_id': pkg.id,
              'course_id': c.id,
              'display_order': order++,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  @override
  Future<List<CoursePackageModel>> getCachedPackages([List<CourseModel>? preloadedCourses]) async {
    final db = await databaseHelper.localDatabase;
    final cachedCourses = preloadedCourses ?? await getCachedCourses();
    final courseMap = {for (final c in cachedCourses) c.id: c};

    final List<Map<String, dynamic>> pkgMaps = await db.query('packages_cache', orderBy: 'title');
    if (pkgMaps.isEmpty) return [];

    // Fetch all package course links in a single query to avoid N+1 query overhead
    final List<Map<String, dynamic>> allItemRows = await db.query(
      'package_courses_cache',
      orderBy: 'package_id, display_order',
    );

    final Map<String, List<CourseModel>> packageCoursesMap = {};
    for (final item in allItemRows) {
      final pkgId = item['package_id'] as String;
      final cId = item['course_id'] as String;
      if (courseMap.containsKey(cId)) {
        packageCoursesMap.putIfAbsent(pkgId, () => []).add(courseMap[cId]!);
      }
    }

    final List<CoursePackageModel> result = [];
    for (final pkgMap in pkgMaps) {
      final pkgId = pkgMap['id'] as String;
      final pkgCourses = packageCoursesMap[pkgId] ?? [];
      result.add(CoursePackageModel.fromCacheMap(pkgMap, courses: pkgCourses));
    }

    return result;
  }

  @override
  Future<bool> isCourseDownloaded(String courseId) async {
    final dbPath = await getCourseDatabasePath(courseId);
    return File(dbPath).existsSync();
  }

  @override
  Future<String> getCourseDatabasePath(String courseId) async {
    final baseDir = await _getBaseCoursesDirectory();
    return p.join(baseDir, courseId, 'course.db');
  }

  @override
  Future<void> markCourseVersionDownloaded(String courseId, int version) async {
    final db = await databaseHelper.localDatabase;
    await db.update(
      'courses_cache',
      {'downloaded_version': version},
      where: 'id = ?',
      whereArgs: [courseId],
    );
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
      final normalizedPath = file.name.replaceAll('\\', '/');
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(p.join(tempExtractDir, normalizedPath));
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(data);
      }
    }

    // 2. Discover SQLite database file (supports root course.db, nested 504/504.db, *.db)
    String? foundDbPath;
    final directDb = File(p.join(tempExtractDir, 'course.db'));
    if (directDb.existsSync()) {
      foundDbPath = directDb.path;
    } else {
      final allFiles = tempDir.listSync(recursive: true);
      for (final entity in allFiles) {
        if (entity is File) {
          final lower = entity.path.toLowerCase();
          if (lower.endsWith('.db') || lower.endsWith('.sqlite')) {
            foundDbPath = entity.path;
            break;
          }
        }
      }
    }

    if (foundDbPath == null) {
      throw Exception('Database file (.db) is missing in the downloaded course package.');
    }

    final tempDbPath = p.join(tempExtractDir, 'course.db');
    if (foundDbPath != tempDbPath) {
      File(foundDbPath).copySync(tempDbPath);
    }

    // 3. Inspect and normalize database schema in tempDbPath
    final courseDb = await openDatabase(tempDbPath, readOnly: false);
    
    try {
      final tableRows = await courseDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");
      final tableNames = tableRows.map((r) => r['name'] as String).toList();
      
      String targetCardTable = 'cards';
      if (!tableNames.contains('cards')) {
        if (tableNames.contains('flashcards')) {
          targetCardTable = 'flashcards';
        } else if (tableNames.isNotEmpty) {
          targetCardTable = tableNames.first;
        }
      }

      final List<Map<String, dynamic>> columnInfo = await courseDb.rawQuery('PRAGMA table_info($targetCardTable)');
      final columnNames = columnInfo.map((c) => (c['name'] as String).toLowerCase()).toList();

      final bool isStandardSchema = tableNames.contains('cards') &&
          columnNames.contains('card_number') &&
          columnNames.contains('question_text') &&
          columnNames.contains('answer_text') &&
          columnNames.contains('id') &&
          columnNames.contains('course_id');

      if (!isStandardSchema) {
        int idxCardNum = columnNames.indexOf('card_number');
        if (idxCardNum == -1) idxCardNum = columnNames.indexOf('number');
        if (idxCardNum == -1) idxCardNum = columnNames.indexOf('id');

        int idxQuestion = columnNames.indexOf('question_text');
        if (idxQuestion == -1) idxQuestion = columnNames.indexOf('questions');
        if (idxQuestion == -1) idxQuestion = columnNames.indexOf('question');
        if (idxQuestion == -1) idxQuestion = columnNames.indexOf('front');

        int idxAnswer = columnNames.indexOf('answer_text');
        if (idxAnswer == -1) idxAnswer = columnNames.indexOf('answer');
        if (idxAnswer == -1) idxAnswer = columnNames.indexOf('answers');
        if (idxAnswer == -1) idxAnswer = columnNames.indexOf('back');

        int idxImage = columnNames.indexOf('image_name');
        if (idxImage == -1) idxImage = columnNames.indexOf('front image');
        if (idxImage == -1) idxImage = columnNames.indexOf('image');
        if (idxImage == -1) idxImage = columnNames.indexOf('image_url');

        int idxAudio = columnNames.indexOf('audio_name');
        if (idxAudio == -1) idxAudio = columnNames.indexOf('front voice');
        if (idxAudio == -1) idxAudio = columnNames.indexOf('audio');
        if (idxAudio == -1) idxAudio = columnNames.indexOf('audio_url');

        final rawRows = await courseDb.query(targetCardTable);
        final List<Map<String, dynamic>> normalizedCards = [];
        int rowCounter = 1;
        for (final r in rawRows) {
          final rawNum = idxCardNum != -1 ? r[columnInfo[idxCardNum]['name']] : null;
          final cardNum = rawNum is int ? rawNum : (int.tryParse(rawNum?.toString() ?? '') ?? rowCounter);
          final qText = idxQuestion != -1 ? (r[columnInfo[idxQuestion]['name']]?.toString() ?? 'Question') : 'Question';
          final aText = idxAnswer != -1 ? (r[columnInfo[idxAnswer]['name']]?.toString() ?? 'Answer') : 'Answer';
          final img = idxImage != -1 ? r[columnInfo[idxImage]['name']]?.toString() : null;
          final aud = idxAudio != -1 ? r[columnInfo[idxAudio]['name']]?.toString() : null;

          normalizedCards.add({
            'id': '${courseId}_$cardNum',
            'course_id': courseId,
            'card_number': cardNum,
            'question_text': qText,
            'answer_text': aText,
            'image_name': (img != null && img.trim().isNotEmpty) ? p.basename(img.trim()) : null,
            'audio_name': (aud != null && aud.trim().isNotEmpty) ? p.basename(aud.trim()) : null,
            'options': null,
          });
          rowCounter++;
        }

        await courseDb.execute('DROP TABLE IF EXISTS cards_temp_norm;');
        await courseDb.execute('''
          CREATE TABLE cards_temp_norm (
            id TEXT PRIMARY KEY,
            course_id TEXT NOT NULL,
            card_number INTEGER NOT NULL,
            question_text TEXT NOT NULL,
            answer_text TEXT NOT NULL,
            image_name TEXT,
            audio_name TEXT,
            options TEXT
          );
        ''');
        await courseDb.execute('CREATE UNIQUE INDEX idx_cards_temp_course_num ON cards_temp_norm (course_id, card_number);');

        final normBatch = courseDb.batch();
        for (final c in normalizedCards) {
          normBatch.insert('cards_temp_norm', c);
        }
        await normBatch.commit(noResult: true);

        await courseDb.execute('DROP TABLE IF EXISTS cards;');
        if (targetCardTable != 'cards') {
          await courseDb.execute('DROP TABLE IF EXISTS $targetCardTable;');
        }
        await courseDb.execute('ALTER TABLE cards_temp_norm RENAME TO cards;');
      }

      // Ensure course table exists in course.db
      await courseDb.execute('''
        CREATE TABLE IF NOT EXISTS course (
          id TEXT PRIMARY KEY,
          title TEXT,
          description TEXT,
          category TEXT,
          difficulty TEXT,
          price REAL DEFAULT 0.0,
          version INTEGER DEFAULT 1,
          created_at TEXT
        );
      ''');
    } finally {
      await courseDb.close();
    }

    // 4. Perform Schema Migration & Progress Synchronization in local db
    final verifiedCourseDb = await databaseHelper.openCourseDatabase(tempDbPath);
    final List<Map<String, dynamic>> cardRows = await verifiedCourseDb.query(
      'cards',
      columns: ['card_number'],
    );
    final newCardNumbers = cardRows.map((row) => (row['card_number'] as num).toInt()).toSet();
    await verifiedCourseDb.close();

    final localDb = await databaseHelper.localDatabase;

    // Get existing local progress for this course
    final List<Map<String, dynamic>> progressRows = await localDb.query(
      'client_progress',
      columns: ['card_number'],
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    final existingCardNumbers = progressRows.map((row) => (row['card_number'] as num).toInt()).toSet();

    // A. Insert defaults for new card numbers added
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cardsToInsert = newCardNumbers.difference(existingCardNumbers);
    final cardsToDelete = existingCardNumbers.difference(newCardNumbers);

    final batch = localDb.batch();
    for (final cardNum in cardsToInsert) {
      final compositeId = '${courseId}_$cardNum';
      batch.insert(
        'client_progress',
        {
          'id': compositeId,
          'course_id': courseId,
          'card_number': cardNum,
          'current_box': 1,
          'last_reviewed_at': null,
          'next_review_due': nowIso,
          'is_synced': 0,
          'has_entered_leitner': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // B. Remove progress records for deleted card numbers
    for (final cardNum in cardsToDelete) {
      final compositeId = '${courseId}_$cardNum';
      batch.delete(
        'client_progress',
        where: 'id = ?',
        whereArgs: [compositeId],
      );
      batch.delete(
        'favorites',
        where: 'course_id = ? AND card_number = ?',
        whereArgs: [courseId, cardNum],
      );
    }

    await batch.commit(noResult: true);

    // 5. Swap the old database with the normalized one
    final targetDbFile = File(p.join(courseDir, 'course.db'));
    if (targetDbFile.existsSync()) {
      targetDbFile.deleteSync();
    }
    File(tempDbPath).copySync(targetDbFile.path);

    // 6. Gather and flatten media files from all extracted locations into courseDir/images and courseDir/audio
    final targetImagesDir = Directory(p.join(courseDir, 'images'));
    final targetAudioDir = Directory(p.join(courseDir, 'audio'));
    if (!targetImagesDir.existsSync()) targetImagesDir.createSync(recursive: true);
    if (!targetAudioDir.existsSync()) targetAudioDir.createSync(recursive: true);

    const audioExts = {'.mp3', '.wav', '.m4a', '.ogg', '.aac', '.opus', '.flac', '.wma'};
    const imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.svg', '.bmp'};

    final allExtractedEntities = tempDir.listSync(recursive: true);
    for (final entity in allExtractedEntities) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        final baseName = p.basename(entity.path);
        if (audioExts.contains(ext)) {
          final dest = p.join(targetAudioDir.path, baseName);
          entity.copySync(dest);
        } else if (imageExts.contains(ext)) {
          final dest = p.join(targetImagesDir.path, baseName);
          entity.copySync(dest);
        }
      }
    }

    // 7. Clean up temporary files
    try {
      tempDir.deleteSync(recursive: true);
      zipFile.deleteSync();
    } catch (_) {}
  }
}
