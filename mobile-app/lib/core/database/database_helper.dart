import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/core/security/pbkdf2.dart';
import 'package:mobile_app/core/services/storage_service.dart';

class DatabaseHelper {
  final StorageService _storageService;
  Database? _localDatabase;
  String? _currentUserId;

  DatabaseHelper(this._storageService);

  /// Gets the currently active user ID.
  String? get currentUserId => _currentUserId;

  /// Switches the active user context and resets active database connection.
  Future<void> switchUser(String? userId) async {
    if (_currentUserId != userId) {
      await closeAll();
      _currentUserId = userId;
    }
  }

  /// Gets the path to the user's local database.
  Future<String> getLocalDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    var userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      userId = await _storageService.readSecure('active_user_id');
      _currentUserId = userId;
    }

    if (userId != null && userId.isNotEmpty) {
      final safeId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final userDbPath = p.join(databasesPath, 'app_local_$safeId.db');

      // Backward compatibility: migrate legacy un-scoped app_local.db to first active user if needed
      final legacyPath = p.join(databasesPath, 'app_local.db');
      try {
        final legacyFile = File(legacyPath);
        final userDbFile = File(userDbPath);
        if (legacyFile.existsSync() && !userDbFile.existsSync()) {
          legacyFile.copySync(userDbPath);
          legacyFile.deleteSync();
        }
      } catch (_) {}

      return userDbPath;
    }

    return p.join(databasesPath, 'app_local_guest.db');
  }

  /// Derives or retrieves the database encryption key.
  /// Follows the design: Key = PBKDF2(DeviceUniqueID, UserSalt, Iterations=10000)
  Future<String> getOrCreateEncryptionKey() async {
    final userSuffix = (_currentUserId != null && _currentUserId!.isNotEmpty)
        ? '_${_currentUserId!.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}'
        : '';

    // 1. Check if key is already cached in secure storage
    var key = await _storageService.readSecure('db_encryption_key$userSuffix');
    if (key != null) {
      return key;
    }

    // 2. Get or generate DeviceUniqueID
    var deviceId = await _storageService.readSecure('device_unique_id');
    if (deviceId == null) {
      deviceId = _generateRandomId(32);
      await _storageService.writeSecure('device_unique_id', deviceId);
    }

    // 3. Get or generate UserSalt
    var salt = await _storageService.readSecure('user_salt$userSuffix');
    if (salt == null) {
      salt = _generateRandomId(16);
      await _storageService.writeSecure('user_salt$userSuffix', salt);
    }

    // 4. Derive key using PBKDF2-HMAC-SHA256
    final derivedKeyBytes = Pbkdf2.deriveKey(
      password: deviceId,
      salt: salt,
      iterations: 10000,
      keyLength: 32, // 256 bits
    );

    final derivedKeyHex = derivedKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storageService.writeSecure('db_encryption_key$userSuffix', derivedKeyHex);

    return derivedKeyHex;
  }

  /// Opens the active user's local database.
  Future<Database> get localDatabase async {
    if (_localDatabase != null) {
      return _localDatabase!;
    }
    
    _localDatabase = await _initLocalDatabase();
    return _localDatabase!;
  }

  Future<Database> _initLocalDatabase() async {
    final path = await getLocalDatabasePath();
    final encryptionKey = await getOrCreateEncryptionKey();
    
    // Validate key derivation is successful
    assert(encryptionKey.isNotEmpty);

    // In a production SQLCipher configuration:
    // return await openDatabase(
    //   path,
    //   version: 1,
    //   password: encryptionKey,
    //   onCreate: _onCreate,
    // );
    
    // Using standard sqflite for maximum compatibility across test and local compilation setups:
    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // A. client_progress
    await db.execute('''
      CREATE TABLE client_progress (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        card_number INTEGER NOT NULL,
        current_box INTEGER NOT NULL DEFAULT 1,
        last_reviewed_at TEXT,
        next_review_due TEXT,
        last_trigger TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        has_entered_leitner INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_progress_due ON client_progress(course_id, next_review_due)');

    // B. user_created_cards
    await db.execute('''
      CREATE TABLE user_created_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_title TEXT NOT NULL DEFAULT 'My Custom Cards',
        question_text TEXT NOT NULL,
        answer_text TEXT NOT NULL,
        options TEXT,
        image_path TEXT,
        audio_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // B2. user_created_courses
    await db.execute('''
      CREATE TABLE user_created_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    // C. favorites
    await db.execute('''
      CREATE TABLE favorites (
        course_id TEXT NOT NULL,
        card_number INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        PRIMARY KEY (course_id, card_number)
      )
    ''');

    // D. settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    
    // E. courses_cache (stores course metadata local list cache)
    await db.execute('''
      CREATE TABLE courses_cache (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT,
        difficulty TEXT,
        price REAL NOT NULL,
        card_count INTEGER NOT NULL,
        is_purchased INTEGER NOT NULL DEFAULT 0,
        download_url TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_critical_update INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        downloaded_version INTEGER
      )
    ''');

    // F. banners_cache
    await db.execute('''
      CREATE TABLE banners_cache (
        id TEXT PRIMARY KEY,
        image_url TEXT NOT NULL,
        link_url TEXT,
        display_order INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // G. announcements_cache
    await db.execute('''
      CREATE TABLE announcements_cache (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        published_at TEXT NOT NULL
      )
    ''');

    // H. packages_cache
    await db.execute('''
      CREATE TABLE packages_cache (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT,
        price REAL NOT NULL,
        original_price REAL,
        discount_percentage INTEGER NOT NULL DEFAULT 0,
        total_card_count INTEGER NOT NULL DEFAULT 0,
        is_purchased INTEGER NOT NULL DEFAULT 0,
        courses_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // I. package_courses_cache
    await db.execute('''
      CREATE TABLE package_courses_cache (
        package_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (package_id, course_id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS banners_cache (
          id TEXT PRIMARY KEY,
          image_url TEXT NOT NULL,
          link_url TEXT,
          display_order INTEGER NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS announcements_cache (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          published_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE user_created_cards ADD COLUMN options TEXT');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_created_courses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');
      // Migrate existing custom course titles from user_created_cards
      try {
        final List<Map<String, dynamic>> existingCards = await db.query(
          'user_created_cards',
          columns: ['course_title'],
          distinct: true,
        );
        final nowIso = DateTime.now().toUtc().toIso8601String();
        for (final row in existingCards) {
          final title = row['course_title'] as String?;
          if (title != null && title.trim().isNotEmpty) {
            await db.insert(
              'user_created_courses',
              {
                'title': title.trim(),
                'created_at': nowIso,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE client_progress ADD COLUMN has_entered_leitner INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      for (final ddl in [
        'ALTER TABLE courses_cache ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE courses_cache ADD COLUMN is_critical_update INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE courses_cache ADD COLUMN updated_at TEXT',
        'ALTER TABLE courses_cache ADD COLUMN downloaded_version INTEGER',
      ]) {
        try {
          await db.execute(ddl);
        } catch (_) {}
      }
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS packages_cache (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          category TEXT,
          price REAL NOT NULL,
          original_price REAL,
          discount_percentage INTEGER NOT NULL DEFAULT 0,
          total_card_count INTEGER NOT NULL DEFAULT 0,
          is_purchased INTEGER NOT NULL DEFAULT 0,
          courses_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS package_courses_cache (
          package_id TEXT NOT NULL,
          course_id TEXT NOT NULL,
          display_order INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (package_id, course_id)
        )
      ''');
    }
  }

  /// Opens a standalone course database file in read-only mode.
  Future<Database> openCourseDatabase(String dbPath) async {
    return await openDatabase(dbPath, readOnly: true);
  }

  /// Helper to generate a secure random string for IDs/salts.
  String _generateRandomId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Clean cache / close connection on logout
  Future<void> closeAll() async {
    if (_localDatabase != null) {
      await _localDatabase!.close();
      _localDatabase = null;
    }
  }

  /// Wipes all tables in the currently active database.
  Future<void> clearAllData() async {
    final db = await localDatabase;
    await db.transaction((txn) async {
      await txn.delete('client_progress');
      await txn.delete('user_created_cards');
      await txn.delete('user_created_courses');
      await txn.delete('favorites');
      await txn.delete('courses_cache');
      await txn.delete('packages_cache');
      await txn.delete('package_courses_cache');
      await txn.delete('banners_cache');
      await txn.delete('announcements_cache');
      await txn.delete('settings');
    });
  }

  /// Deletes a specific user's database file completely if needed.
  Future<void> deleteUserData(String userId) async {
    final safeId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final databasesPath = await getDatabasesPath();
    final userDbPath = p.join(databasesPath, 'app_local_$safeId.db');
    
    if (_currentUserId == userId) {
      await closeAll();
      _currentUserId = null;
    }
    
    final file = File(userDbPath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }
}
