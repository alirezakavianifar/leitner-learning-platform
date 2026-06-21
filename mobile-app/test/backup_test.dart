import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/core/services/backup_service.dart';

class FakeDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> tables = {};

  FakeDatabase() {
    tables['client_progress'] = [];
    tables['user_created_cards'] = [];
    tables['favorites'] = [];
    tables['settings'] = [];
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return tables[table] ?? [];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    tables.putIfAbsent(table, () => []);
    tables[table]!.add(Map<String, dynamic>.from(values));
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    tables[table] = [];
    return 0;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final fakeTxn = FakeTransaction(this);
    return await action(fakeTxn as Transaction);
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Method ${invocation.memberName} not implemented in FakeDatabase');
  }
}

class FakeTransaction implements Transaction {
  final FakeDatabase db;
  FakeTransaction(this.db);

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    return await db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Method ${invocation.memberName} not implemented in FakeTransaction');
  }
}

class FakeDatabaseHelper extends DatabaseHelper {
  final FakeDatabase localDb;
  FakeDatabaseHelper(this.localDb) : super(FakeStorageService());

  @override
  Future<Database> get localDatabase async => localDb;
}

class FakeStorageService implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDatabase localDb;
  late FakeDatabaseHelper databaseHelper;
  late OfflineBackupService backupService;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.'; // Mock app documents directory in current path
      },
    );

    localDb = FakeDatabase();
    databaseHelper = FakeDatabaseHelper(localDb);
    backupService = OfflineBackupService(databaseHelper);

    // Setup initial data
    localDb.tables['client_progress'] = [
      {'id': 'c1_1', 'course_id': 'c1', 'card_number': 1, 'current_box': 3, 'last_reviewed_at': '2026-06-21T00:00:00Z', 'next_review_due': '2026-06-24T00:00:00Z', 'is_synced': 1}
    ];
    localDb.tables['user_created_cards'] = [
      {'id': 1, 'course_title': 'My Cards', 'question_text': 'Q1', 'answer_text': 'A1', 'created_at': '2026-06-21T01:00:00Z'}
    ];
    localDb.tables['favorites'] = [
      {'course_id': 'c1', 'card_number': 1, 'added_at': '2026-06-21T02:00:00Z'}
    ];
    localDb.tables['settings'] = [
      {'key': 'theme', 'value': 'dark'}
    ];
  });

  tearDown(() {
    try {
      final dir = Directory('backups');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Offline Backup & Restore Service Tests', () {
    test('Should export encrypted backup file successfully', () async {
      final path = await backupService.exportBackup('supersecretpwd123');
      expect(path, isNotNull);
      
      final file = File(path);
      expect(file.existsSync(), true);

      final content = file.readAsStringSync();
      expect(content.contains(':'), true);
    });

    test('Should decrypt and restore backup successfully with correct password', () async {
      final path = await backupService.exportBackup('supersecretpwd123');

      // Clear current memory database
      localDb.tables['client_progress'] = [];
      localDb.tables['user_created_cards'] = [];
      localDb.tables['favorites'] = [];
      localDb.tables['settings'] = [];

      // Restore
      final result = await backupService.importBackup(path, 'supersecretpwd123');
      expect(result, true);

      // Verify records are restored
      expect(localDb.tables['client_progress']!.length, 1);
      expect(localDb.tables['client_progress']!.first['id'], 'c1_1');
      expect(localDb.tables['user_created_cards']!.length, 1);
      expect(localDb.tables['favorites']!.length, 1);
      expect(localDb.tables['settings']!.length, 1);
    });

    test('Should throw exception when attempting restore with incorrect password', () async {
      final path = await backupService.exportBackup('supersecretpwd123');

      expect(
        () async => await backupService.importBackup(path, 'wrongpassword'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
