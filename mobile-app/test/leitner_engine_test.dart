import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/features/flashcards/data/models/card_progress_model.dart';
import 'package:mobile_app/features/flashcards/data/repositories/flashcard_repository_impl.dart';

// --- Fakes for Sqflite and Core Services ---

class FakeDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> tables = {};

  FakeDatabase() {
    tables['client_progress'] = [];
    tables['cards'] = [];
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
    var list = tables[table] ?? [];
    
    if (where != null && whereArgs != null) {
      if (where.contains('course_id = ? AND current_box >= 2 AND current_box <= 5 AND next_review_due < ?')) {
        final courseId = whereArgs[0] as String;
        final startOfToday = DateTime.parse(whereArgs[1] as String);
        list = list.where((row) {
          if (row['course_id'] != courseId) return false;
          final box = row['current_box'] as int;
          if (box < 2 || box > 5) return false;
          if (row['next_review_due'] == null) return false;
          final due = DateTime.parse(row['next_review_due'] as String);
          return due.isBefore(startOfToday);
        }).toList();
      }
      else if (where.contains('course_id = ? AND card_number = ?')) {
        final courseId = whereArgs[0];
        final cardNum = whereArgs[1];
        list = list.where((row) => row['course_id'] == courseId && row['card_number'] == cardNum).toList();
      }
      else if (where.contains('course_id = ?')) {
        final courseId = whereArgs[0];
        list = list.where((row) => row['course_id'] == courseId).toList();
      }
      else if (where.contains('is_synced = 0')) {
        list = list.where((row) => row['is_synced'] == 0).toList();
      }
      else if (where.contains('card_number = ?')) {
        final cardNum = whereArgs[0];
        list = list.where((row) => row['card_number'] == cardNum).toList();
      }
    }

    if (orderBy == 'card_number') {
      final mutable = List<Map<String, dynamic>>.from(list);
      mutable.sort((a, b) => (a['card_number'] as int).compareTo(b['card_number'] as int));
      list = mutable;
    }

    return list;
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
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables[table] ?? [];
    int count = 0;

    if (where != null && whereArgs != null) {
      if (where == 'id = ?') {
        final id = whereArgs[0] as String;
        for (int i = 0; i < list.length; i++) {
          if (list[i]['id'] == id) {
            final updatedMap = Map<String, dynamic>.from(list[i])..addAll(values);
            list[i] = updatedMap;
            count++;
          }
        }
      }
      else if (where == 'course_id = ? AND card_number = ?') {
        final courseId = whereArgs[0];
        final cardNum = whereArgs[1];
        for (int i = 0; i < list.length; i++) {
          if (list[i]['course_id'] == courseId && list[i]['card_number'] == cardNum) {
            final updatedMap = Map<String, dynamic>.from(list[i])..addAll(values);
            list[i] = updatedMap;
            count++;
          }
        }
      }
    }
    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
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
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Method ${invocation.memberName} not implemented in FakeTransaction');
  }
}

class FakeDatabaseHelper extends DatabaseHelper {
  final FakeDatabase localDb;
  final FakeDatabase courseDb;

  FakeDatabaseHelper(this.localDb, this.courseDb) : super(FakeStorageService());

  @override
  Future<Database> get localDatabase async => localDb;

  @override
  Future<Database> openCourseDatabase(String dbPath) async => courseDb;
}

class FakeStorageService implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeDio implements Dio {
  int postCallCount = 0;
  dynamic lastPayload;
  int statusCode = 200;

  @override
  final BaseOptions options = BaseOptions();

  @override
  final Interceptors interceptors = Interceptors();

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    postCallCount++;
    lastPayload = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: {'success': true} as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Method ${invocation.memberName} not implemented in FakeDio');
  }
}

class FakeDioClient extends DioClient {
  final FakeDio fakeDio;
  FakeDioClient(this.fakeDio) : super(dio: fakeDio, storageService: FakeStorageService(), baseUrl: '');

  @override
  Dio get dio => fakeDio;
}

// --- Leitner Engine Test Suite ---

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDatabase localDb;
  late FakeDatabase courseDb;
  late FakeDatabaseHelper databaseHelper;
  late FakeDio fakeDio;
  late FakeDioClient dioClient;
  late EventBus eventBus;
  late FlashcardRepositoryImpl repository;

  final courseId = 'test-course-id';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.'; // Mock app documents directory in current path
      },
    );

    localDb = FakeDatabase();
    courseDb = FakeDatabase();
    databaseHelper = FakeDatabaseHelper(localDb, courseDb);
    fakeDio = FakeDio();
    dioClient = FakeDioClient(fakeDio);
    eventBus = EventBus();

    repository = FlashcardRepositoryImpl(
      databaseHelper: databaseHelper,
      dioClient: dioClient,
      eventBus: eventBus,
    );

    // Setup course db cards
    courseDb.tables['cards'] = [
      {'id': 'c1', 'course_id': courseId, 'card_number': 1, 'question_text': 'Q1', 'answer_text': 'A1'},
      {'id': 'c2', 'course_id': courseId, 'card_number': 2, 'question_text': 'Q2', 'answer_text': 'A2'},
      {'id': 'c3', 'course_id': courseId, 'card_number': 3, 'question_text': 'Q3', 'answer_text': 'A3'},
    ];

    // Create a dummy course.db file for existence checks
    Directory('courses/$courseId').createSync(recursive: true);
    File('courses/$courseId/course.db').createSync();
  });

  tearDown(() {
    eventBus.destroy();
    // Clean up dummy directories
    try {
      Directory('courses').deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Leitner Engine Progression Rules', () {
    test('Correct review: Box 1 to Box 2 should schedule review after 3 days', () async {
      // Arrange - Box 1 progress
      final id = '${courseId}_1';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 1,
        'last_reviewed_at': null,
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': null,
        'is_synced': 0,
      });

      // Assert event fires
      CardReviewed? reviewEvent;
      eventBus.on<CardReviewed>().listen((e) => reviewEvent = e);

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 1, isCorrect: true);
      await Future.delayed(Duration.zero);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 2);
      expect(progress.lastTrigger, 'REVIEW_CORRECT');
      expect(progress.isSynced, false);
      expect(progress.nextReviewDue!.difference(progress.lastReviewedAt!).inDays, 3);
      expect(reviewEvent, isNotNull);
      expect(reviewEvent!.box, 2);
    });

    test('Submit review for card with no prior progress record: should initialize, insert default Box 1 entry, and progress to Box 2', () async {
      // Arrange - client_progress is empty (no prior progress record exists)
      expect(localDb.tables['client_progress']!, isEmpty);

      // Assert event fires
      CardReviewed? reviewEvent;
      eventBus.on<CardReviewed>().listen((e) => reviewEvent = e);

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 1, isCorrect: true);
      await Future.delayed(Duration.zero);

      // Assert - entry should have been created and updated to Box 2
      expect(localDb.tables['client_progress']!.length, 1);
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.cardNumber, 1);
      expect(progress.currentBox, 2);
      expect(progress.lastTrigger, 'REVIEW_CORRECT');
      expect(progress.isSynced, false);
      expect(progress.nextReviewDue!.difference(progress.lastReviewedAt!).inDays, 3);
      expect(reviewEvent, isNotNull);
      expect(reviewEvent!.box, 2);
    });

    test('Correct review: Box 4 to Box 5 should schedule review after 31 days', () async {
      // Arrange - Box 4 progress
      final id = '${courseId}_2';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 2,
        'current_box': 4,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 2, isCorrect: true);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 5);
      expect(progress.nextReviewDue!.difference(progress.lastReviewedAt!).inDays, 31);
      expect(progress.isSynced, false);
    });

    test('Correct review: Box 5 to Finished (Box 6) should clear review due date', () async {
      // Arrange - Box 5 progress
      final id = '${courseId}_3';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 3,
        'current_box': 5,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      CardFinished? finishedEvent;
      eventBus.on<CardFinished>().listen((e) => finishedEvent = e);

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 3, isCorrect: true);
      await Future.delayed(Duration.zero);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 6);
      expect(progress.nextReviewDue, isNull);
      expect(finishedEvent, isNotNull);
      expect(finishedEvent!.cardNumber, 3);
    });

    test('Incorrect review: Box 3 should reset to Box 1 immediately', () async {
      // Arrange
      final id = '${courseId}_1';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 3,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      CardReviewed? reviewEvent;
      eventBus.on<CardReviewed>().listen((e) => reviewEvent = e);

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 1, isCorrect: false);
      await Future.delayed(Duration.zero);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 1);
      expect(progress.lastTrigger, 'REVIEW_INCORRECT');
      expect(reviewEvent!.box, 1);
    });

    test('Finished cards correct review: Keeps card in Finished pool (No Action)', () async {
      // Arrange
      final id = '${courseId}_1';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 6,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': null,
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 1, isCorrect: true);

      // Assert - unchanged
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 6);
      expect(progress.nextReviewDue, isNull);
    });

    test('Finished cards incorrect review: Resets progress immediately to Box 1', () async {
      // Arrange
      final id = '${courseId}_1';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 6,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': null,
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      // Act
      await repository.submitReview(courseId: courseId, cardNumber: 1, isCorrect: false);

      // Assert - returns to Box 1
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 1);
      expect(progress.lastTrigger, 'REVIEW_INCORRECT');
    });
  });

  group('Leitner Engine Reset Rules', () {
    test('Rule A: Due card not reviewed on due day (overdue) resets to Box 1', () async {
      // Arrange - card in box 3 due yesterday
      final id = '${courseId}_1';
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 3,
        'last_reviewed_at': yesterday.subtract(const Duration(days: 7)).toIso8601String(),
        'next_review_due': yesterday.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      DueDateOverdueReset? overdueEvent;
      eventBus.on<DueDateOverdueReset>().listen((e) => overdueEvent = e);

      // Act
      await repository.checkForOverdueResets(courseId);
      await Future.delayed(Duration.zero);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 1);
      expect(progress.lastTrigger, 'OVERDUE_RESET');
      expect(progress.isSynced, false);
      expect(overdueEvent, isNotNull);
      expect(overdueEvent!.cardNumber, 1);
    });

    test('Rule A: Due card due TODAY should NOT reset', () async {
      // Arrange - card in box 3 due in 4 hours
      final id = '${courseId}_1';
      final dueToday = DateTime.now().add(const Duration(hours: 4));
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 3,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': dueToday.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      // Act
      await repository.checkForOverdueResets(courseId);

      // Assert - remains unchanged
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 3);
    });

    test('Rule B: Manual Favorites view reset prompts reset to Box 1', () async {
      // Arrange
      final id = '${courseId}_1';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 3,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      LeitnerProgressReset? resetEvent;
      eventBus.on<LeitnerProgressReset>().listen((e) => resetEvent = e);

      // Act
      await repository.resetCardProgress(courseId: courseId, cardNumber: 1, reason: 'favorites');
      await Future.delayed(Duration.zero);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 1);
      expect(progress.lastTrigger, 'FAVORITES_RESET');
      expect(resetEvent, isNotNull);
      expect(resetEvent!.reason, 'FAVORITES_RESET');
    });

    test('Rule C: Manual Jump view reset prompts reset to Box 1', () async {
      // Arrange
      final id = '${courseId}_1';
      localDb.tables['client_progress']!.add({
        'id': id,
        'course_id': courseId,
        'card_number': 1,
        'current_box': 2,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      LeitnerProgressReset? resetEvent;
      eventBus.on<LeitnerProgressReset>().listen((e) => resetEvent = e);

      // Act
      await repository.resetCardProgress(courseId: courseId, cardNumber: 1, reason: 'jump');
      await Future.delayed(Duration.zero);

      // Assert
      final progress = CardProgressModel.fromMap(localDb.tables['client_progress']!.first);
      expect(progress.currentBox, 1);
      expect(progress.lastTrigger, 'JUMP_RESET');
      expect(resetEvent, isNotNull);
      expect(resetEvent!.reason, 'JUMP_RESET');
    });
  });

  group('Leitner Engine Review Queue Restrictions', () {
    test('Review queue: returns Box 1 and active due cards from Boxes 2-5; excludes non-due Box 2 cards', () async {
      // Setup progress in local DB
      // Card 1: Box 1 (Due)
      localDb.tables['client_progress']!.add({
        'id': '${courseId}_1',
        'course_id': courseId,
        'card_number': 1,
        'current_box': 1,
        'last_reviewed_at': null,
        'next_review_due': DateTime.now().toIso8601String(),
        'last_trigger': null,
        'is_synced': 0,
      });
      // Card 2: Box 2, due yesterday (Due)
      localDb.tables['client_progress']!.add({
        'id': '${courseId}_2',
        'course_id': courseId,
        'card_number': 2,
        'current_box': 2,
        'last_reviewed_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'next_review_due': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });
      // Card 3: Box 2, due tomorrow (NOT Due)
      localDb.tables['client_progress']!.add({
        'id': '${courseId}_3',
        'course_id': courseId,
        'card_number': 3,
        'current_box': 2,
        'last_reviewed_at': DateTime.now().toIso8601String(),
        'next_review_due': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 1,
      });

      // Act
      final queue = await repository.getReviewQueue(courseId);

      // Assert - queue should contain Card 1 and Card 2, but NOT Card 3!
      expect(queue.length, 2);
      expect(queue[0].cardNumber, 1);
      expect(queue[1].cardNumber, 2);
    });
  });

  group('Leitner Engine Progress Sync API client', () {
    test('syncProgress: uploads deltas to /statistics/sync and updates local states', () async {
      // Arrange - 2 unsynced progress entries
      localDb.tables['client_progress']!.addAll([
        {
          'id': '${courseId}_1',
          'course_id': courseId,
          'card_number': 1,
          'current_box': 2,
          'last_reviewed_at': DateTime.now().toIso8601String(),
          'next_review_due': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'last_trigger': 'REVIEW_CORRECT',
          'is_synced': 0,
        },
        {
          'id': '${courseId}_2',
          'course_id': courseId,
          'card_number': 2,
          'current_box': 1,
          'last_reviewed_at': DateTime.now().toIso8601String(),
          'next_review_due': DateTime.now().toIso8601String(),
          'last_trigger': 'REVIEW_INCORRECT',
          'is_synced': 0,
        }
      ]);

      // Act
      await repository.syncProgress();

      // Assert
      expect(fakeDio.postCallCount, 1);
      expect(fakeDio.lastPayload, isNotNull);
      final payload = fakeDio.lastPayload as Map<String, dynamic>;
      expect(payload['progress_deltas'].length, 2);
      expect(payload['progress_deltas'][0]['trigger'], 'REVIEW_CORRECT');
      expect(payload['progress_deltas'][1]['trigger'], 'REVIEW_INCORRECT');

      // Local entries should be marked as is_synced = 1
      final progressList = localDb.tables['client_progress']!;
      expect(progressList[0]['is_synced'], 1);
      expect(progressList[1]['is_synced'], 1);
    });
  });
}
