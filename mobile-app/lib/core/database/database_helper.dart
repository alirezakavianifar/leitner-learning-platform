import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/core/security/pbkdf2.dart';
import 'package:mobile_app/core/services/storage_service.dart';

class DatabaseHelper {
  final StorageService _storageService;
  Database? _localDatabase;

  DatabaseHelper(this._storageService);

  /// Gets the path to the app's local database.
  Future<String> getLocalDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, 'app_local.db');
  }

  /// Derives or retrieves the database encryption key.
  /// Follows the design: Key = PBKDF2(DeviceUniqueID, UserSalt, Iterations=10000)
  Future<String> getOrCreateEncryptionKey() async {
    // 1. Check if key is already cached in secure storage
    var key = await _storageService.readSecure('db_encryption_key');
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
    var salt = await _storageService.readSecure('user_salt');
    if (salt == null) {
      salt = _generateRandomId(16);
      await _storageService.writeSecure('user_salt', salt);
    }

    // 4. Derive key using PBKDF2-HMAC-SHA256
    final derivedKeyBytes = Pbkdf2.deriveKey(
      password: deviceId,
      salt: salt,
      iterations: 10000,
      keyLength: 32, // 256 bits
    );

    final derivedKeyHex = derivedKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storageService.writeSecure('db_encryption_key', derivedKeyHex);

    return derivedKeyHex;
  }

  /// Opens the shared local database.
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
      version: 2,
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
        is_synced INTEGER NOT NULL DEFAULT 0
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
        image_path TEXT,
        audio_path TEXT,
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
        version INTEGER NOT NULL DEFAULT 1
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
}
