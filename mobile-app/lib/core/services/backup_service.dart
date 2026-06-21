import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/security/pbkdf2.dart';
import 'package:sqflite/sqflite.dart';

class OfflineBackupService {
  final DatabaseHelper databaseHelper;

  OfflineBackupService(this.databaseHelper);

  /// Helper to get the backups directory path.
  Future<String> getBackupsDirectoryPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docDir.path, 'backups'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }
    return backupDir.path;
  }

  /// Exports the local database tables into an encrypted backup file.
  Future<String> exportBackup(String password) async {
    final localDb = await databaseHelper.localDatabase;

    // 1. Read all tables
    final clientProgress = await localDb.query('client_progress');
    final userCreatedCards = await localDb.query('user_created_cards');
    final favorites = await localDb.query('favorites');
    final settings = await localDb.query('settings');

    // 2. Build JSON payload
    final backupData = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'client_progress': clientProgress,
      'user_created_cards': userCreatedCards,
      'favorites': favorites,
      'settings': settings,
    };

    final plainText = jsonEncode(backupData);

    // 3. Derive 256-bit key from password using PBKDF2
    final keyBytes = Pbkdf2.deriveKey(
      password: password,
      salt: 'leitner_backup_salt_2026',
      iterations: 10000,
      keyLength: 32,
    );
    final key = enc.Key(keyBytes);

    // 4. Generate random IV
    final iv = enc.IV.fromSecureRandom(16);

    // 5. Encrypt
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // 6. Format file content as: IV_base64:Ciphertext_base64
    final fileContent = '${iv.base64}:${encrypted.base64}';

    // 7. Write to backup file
    final backupDir = await getBackupsDirectoryPath();
    final filename = 'backup_${DateTime.now().millisecondsSinceEpoch}.enc';
    final file = File(p.join(backupDir, filename));
    await file.writeAsString(fileContent);

    return file.path;
  }

  /// Imports an encrypted backup file and restores local database tables.
  Future<bool> importBackup(String filePath, String password) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return false;
    }

    final content = await file.readAsString();
    final parts = content.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid backup file format.');
    }

    final ivBase64 = parts[0];
    final ciphertextBase64 = parts[1];

    // 1. Derive key
    final keyBytes = Pbkdf2.deriveKey(
      password: password,
      salt: 'leitner_backup_salt_2026',
      iterations: 10000,
      keyLength: 32,
    );
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromBase64(ivBase64);

    // 2. Decrypt
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    String plainText;
    try {
      plainText = encrypter.decrypt(enc.Encrypted.fromBase64(ciphertextBase64), iv: iv);
    } catch (_) {
      throw Exception('Incorrect password or corrupted backup file.');
    }

    // 3. Deserialize JSON
    final Map<String, dynamic> backupData = jsonDecode(plainText);
    if (backupData['version'] != 1) {
      throw Exception('Unsupported backup version.');
    }

    final List<dynamic> clientProgress = backupData['client_progress'] ?? [];
    final List<dynamic> userCreatedCards = backupData['user_created_cards'] ?? [];
    final List<dynamic> favorites = backupData['favorites'] ?? [];
    final List<dynamic> settings = backupData['settings'] ?? [];

    final localDb = await databaseHelper.localDatabase;

    // 4. Restore tables inside transaction
    await localDb.transaction((txn) async {
      // Clear current data
      await txn.delete('client_progress');
      await txn.delete('user_created_cards');
      await txn.delete('favorites');
      await txn.delete('settings');

      // Insert client_progress
      for (final row in clientProgress) {
        await txn.insert('client_progress', Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Insert user_created_cards
      for (final row in userCreatedCards) {
        await txn.insert('user_created_cards', Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Insert favorites
      for (final row in favorites) {
        await txn.insert('favorites', Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Insert settings
      for (final row in settings) {
        await txn.insert('settings', Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    return true;
  }
}
