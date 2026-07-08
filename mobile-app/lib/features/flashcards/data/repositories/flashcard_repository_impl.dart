import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/data/models/card_progress_model.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';

class FlashcardRepositoryImpl implements FlashcardRepository {
  final DatabaseHelper databaseHelper;
  final DioClient dioClient;
  final EventBus eventBus;

  FlashcardRepositoryImpl({
    required this.databaseHelper,
    required this.dioClient,
    required this.eventBus,
  });

  Future<String> _getCourseDatabasePath(String courseId) async {
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'courses', courseId, 'course.db');
  }

  @override
  Future<List<Flashcard>> getReviewQueue(String courseId, {bool isTodayReview = false}) async {
    // 1. Run the Rule A checks first to reset any overdue cards
    await checkForOverdueResets(courseId);

    final dbPath = await _getCourseDatabasePath(courseId);
    if (!File(dbPath).existsSync()) {
      return [];
    }

    final courseDb = await databaseHelper.openCourseDatabase(dbPath);
    final List<Map<String, dynamic>> cardMaps = await courseDb.query('cards', orderBy: 'card_number');
    await courseDb.close();

    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> progressMaps = await localDb.query(
      'client_progress',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );

    final progressMap = {
      for (final map in progressMaps)
        map['card_number'] as int: CardProgressModel.fromMap(map)
    };

    final List<Flashcard> reviewQueue = [];
    final now = DateTime.now();

    for (final cardMap in cardMaps) {
      final cardNum = cardMap['card_number'] as int;
      var progress = progressMap[cardNum];

      if (progress == null) {
        // Fallback default
        progress = CardProgressModel(
          id: '${courseId}_$cardNum',
          courseId: courseId,
          cardNumber: cardNum,
          currentBox: 1,
          lastReviewedAt: null,
          nextReviewDue: now,
          lastTrigger: null,
          isSynced: false,
          hasEnteredLeitner: false,
        );
      }

      // Progression filter:
      // 1. In Today's Reviews: Box 1 (always due) + Box 2-5 (if nextReviewDue <= now).
      // 2. In Direct Course Study: Box 1 + Box 6 (Finished) only. Boxes 2-5 are hidden.
      final bool included;
      if (isTodayReview) {
        included = progress.currentBox >= 1 &&
            progress.currentBox <= 5 &&
            progress.nextReviewDue != null &&
            progress.nextReviewDue!.isBefore(now.add(const Duration(seconds: 1)));
      } else {
        included = progress.currentBox == 1 || progress.currentBox == 6;
      }

      if (included) {
        List<String>? optionsList;
        final optionsStr = cardMap['options'] as String?;
        if (optionsStr != null && optionsStr.isNotEmpty) {
          try {
            final parsed = jsonDecode(optionsStr);
            if (parsed is List) {
              optionsList = parsed.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        }

        reviewQueue.add(
          Flashcard(
            id: cardMap['id'] as String,
            courseId: courseId,
            cardNumber: cardNum,
            questionText: cardMap['question_text'] as String,
            answerText: cardMap['answer_text'] as String,
            imageUrl: (cardMap['image_name'] ?? cardMap['image_url']) as String?,
            audioUrl: (cardMap['audio_name'] ?? cardMap['audio_url']) as String?,
            options: optionsList,
            progress: progress,
          ),
        );
      }
    }

    return reviewQueue;
  }

  @override
  Future<void> submitReview({
    required String courseId,
    required int cardNumber,
    required bool isCorrect,
  }) async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await localDb.query(
      'client_progress',
      where: 'course_id = ? AND card_number = ?',
      whereArgs: [courseId, cardNumber],
    );

    final now = DateTime.now();
    CardProgressModel currentProgress;
    if (maps.isEmpty) {
      currentProgress = CardProgressModel(
        id: '${courseId}_$cardNumber',
        courseId: courseId,
        cardNumber: cardNumber,
        currentBox: 1,
        lastReviewedAt: null,
        nextReviewDue: now,
        lastTrigger: null,
        isSynced: false,
        hasEnteredLeitner: false,
      );
      await localDb.insert(
        'client_progress',
        currentProgress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      currentProgress = CardProgressModel.fromMap(maps.first);
    }

    int newBox = currentProgress.currentBox;
    DateTime? newNextReviewDue = currentProgress.nextReviewDue;
    String? trigger;

    if (isCorrect) {
      if (currentProgress.currentBox == 6) {
        // Finished cards remain finished, no action
        return;
      }

      trigger = 'REVIEW_CORRECT';
      if (currentProgress.currentBox == 5) {
        newBox = 6;
        newNextReviewDue = null;
        eventBus.fire(CardFinished(
          courseId: courseId,
          cardNumber: cardNumber,
          finishedAt: now,
        ));
      } else {
        newBox = currentProgress.currentBox + 1;
        int days = 0;
        if (newBox == 2) days = 3;
        if (newBox == 3) days = 7;
        if (newBox == 4) days = 16;
        if (newBox == 5) days = 31;
        newNextReviewDue = now.add(Duration(days: days));
        eventBus.fire(CardReviewed(
          courseId: courseId,
          cardNumber: cardNumber,
          box: newBox,
          reviewedAt: now,
        ));
      }
    } else {
      // Incorrect review
      trigger = 'REVIEW_INCORRECT';
      newBox = 1;
      newNextReviewDue = now; // immediately due again
      eventBus.fire(CardReviewed(
        courseId: courseId,
        cardNumber: cardNumber,
        box: 1,
        reviewedAt: now,
      ));
    }

    final updated = CardProgressModel(
      id: currentProgress.id,
      courseId: courseId,
      cardNumber: cardNumber,
      currentBox: newBox,
      lastReviewedAt: now,
      nextReviewDue: newNextReviewDue,
      lastTrigger: trigger,
      isSynced: false,
      hasEnteredLeitner: currentProgress.hasEnteredLeitner || isCorrect,
    );

    await localDb.update(
      'client_progress',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [currentProgress.id],
    );
  }

  @override
  Future<void> resetCardProgress({
    required String courseId,
    required int cardNumber,
    required String reason,
  }) async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await localDb.query(
      'client_progress',
      where: 'course_id = ? AND card_number = ?',
      whereArgs: [courseId, cardNumber],
    );

    if (maps.isEmpty) return;

    final currentProgress = CardProgressModel.fromMap(maps.first);
    if (currentProgress.currentBox == 1) return; // already in Box 1

    final now = DateTime.now();
    final trigger = reason.toUpperCase() == 'FAVORITES' ? 'FAVORITES_RESET' : 'JUMP_RESET';

    final updated = CardProgressModel(
      id: currentProgress.id,
      courseId: courseId,
      cardNumber: cardNumber,
      currentBox: 1,
      lastReviewedAt: now,
      nextReviewDue: now,
      lastTrigger: trigger,
      isSynced: false,
      hasEnteredLeitner: false,
    );

    await localDb.update(
      'client_progress',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [currentProgress.id],
    );

    eventBus.fire(LeitnerProgressReset(
      courseId: courseId,
      cardNumber: cardNumber,
      resetAt: now,
      reason: trigger,
    ));
  }

  @override
  Future<void> checkForOverdueResets(String courseId) async {
    final localDb = await databaseHelper.localDatabase;
    final now = DateTime.now();
    final startOfTodayLocal = DateTime(now.year, now.month, now.day);
    final startOfTodayUtcStr = startOfTodayLocal.toUtc().toIso8601String();

    // Query active Leitner cards (Boxes 2-5) whose nextReviewDue is strictly before the start of today local time
    final List<Map<String, dynamic>> overdueMaps = await localDb.query(
      'client_progress',
      where: 'course_id = ? AND current_box >= 2 AND current_box <= 5 AND next_review_due < ?',
      whereArgs: [courseId, startOfTodayUtcStr],
    );

    for (final map in overdueMaps) {
      final currentProgress = CardProgressModel.fromMap(map);
      
      final updated = CardProgressModel(
        id: currentProgress.id,
        courseId: courseId,
        cardNumber: currentProgress.cardNumber,
        currentBox: 1,
        lastReviewedAt: now,
        nextReviewDue: now,
        lastTrigger: 'OVERDUE_RESET',
        isSynced: false,
        hasEnteredLeitner: currentProgress.hasEnteredLeitner,
      );

      await localDb.update(
        'client_progress',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [currentProgress.id],
      );

      eventBus.fire(DueDateOverdueReset(
        courseId: courseId,
        cardNumber: currentProgress.cardNumber,
        resetAt: now,
      ));
    }
  }

  @override
  Future<void> syncProgress() async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> unsyncedMaps = await localDb.query(
      'client_progress',
      where: 'is_synced = 0',
    );

    if (unsyncedMaps.isEmpty) return;

    final deltas = unsyncedMaps.map((map) {
      final model = CardProgressModel.fromMap(map);
      return {
        'course_id': model.courseId,
        'card_number': model.cardNumber,
        'current_box': model.currentBox,
        'last_reviewed_at': model.lastReviewedAt?.toUtc().toIso8601String(),
        'next_review_due': model.nextReviewDue?.toUtc().toIso8601String(),
        'trigger': model.lastTrigger,
      };
    }).toList();

    final payload = {
      'sync_time': DateTime.now().toUtc().toIso8601String(),
      'progress_deltas': deltas,
    };

    try {
      final response = await dioClient.dio.post('/statistics/sync', data: payload);
      if (response.statusCode == 200) {
        // Mark as synced in local DB
        await localDb.transaction((txn) async {
          for (final map in unsyncedMaps) {
            await txn.update(
              'client_progress',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [map['id']],
            );
          }
        });
      }
    } catch (_) {
      // Fail silently or handle connection error (sync runs again next time)
    }
  }

  @override
  Future<Map<int, int>> getCourseStatistics(String courseId) async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await localDb.query(
      'client_progress',
      columns: ['current_box', 'COUNT(*) as count'],
      where: 'course_id = ?',
      whereArgs: [courseId],
      groupBy: 'current_box',
    );

    final stats = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (final map in maps) {
      final box = map['current_box'] as int;
      final count = map['count'] as int;
      if (stats.containsKey(box)) {
        stats[box] = count;
      }
    }
    return stats;
  }

  @override
  Future<Flashcard?> getCardByNumber(String courseId, int cardNumber) async {
    final dbPath = await _getCourseDatabasePath(courseId);
    if (!File(dbPath).existsSync()) {
      return null;
    }

    final courseDb = await databaseHelper.openCourseDatabase(dbPath);
    final List<Map<String, dynamic>> cardMaps = await courseDb.query(
      'cards',
      where: 'card_number = ?',
      whereArgs: [cardNumber],
    );
    await courseDb.close();

    if (cardMaps.isEmpty) return null;

    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> progressMaps = await localDb.query(
      'client_progress',
      where: 'course_id = ? AND card_number = ?',
      whereArgs: [courseId, cardNumber],
    );

    var progress = progressMaps.isNotEmpty 
        ? CardProgressModel.fromMap(progressMaps.first)
        : CardProgressModel(
            id: '${courseId}_$cardNumber',
            courseId: courseId,
            cardNumber: cardNumber,
            currentBox: 1,
            lastReviewedAt: null,
            nextReviewDue: DateTime.now(),
            lastTrigger: null,
            isSynced: false,
            hasEnteredLeitner: false,
          );

    final cardMap = cardMaps.first;
    List<String>? optionsList;
    final optionsStr = cardMap['options'] as String?;
    if (optionsStr != null && optionsStr.isNotEmpty) {
      try {
        final parsed = jsonDecode(optionsStr);
        if (parsed is List) {
          optionsList = parsed.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return Flashcard(
      id: cardMap['id'] as String,
      courseId: courseId,
      cardNumber: cardNumber,
      questionText: cardMap['question_text'] as String,
      answerText: cardMap['answer_text'] as String,
      imageUrl: (cardMap['image_name'] ?? cardMap['image_url']) as String?,
      audioUrl: (cardMap['audio_name'] ?? cardMap['audio_url']) as String?,
      options: optionsList,
      progress: progress,
    );
  }

  @override
  Future<void> toggleFavorite({
    required String courseId,
    required int cardNumber,
  }) async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await localDb.query(
      'favorites',
      where: 'course_id = ? AND card_number = ?',
      whereArgs: [courseId, cardNumber],
    );

    if (maps.isEmpty) {
      await localDb.insert(
        'favorites',
        {
          'course_id': courseId,
          'card_number': cardNumber,
          'added_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } else {
      await localDb.delete(
        'favorites',
        where: 'course_id = ? AND card_number = ?',
        whereArgs: [courseId, cardNumber],
      );
    }
  }

  @override
  Future<bool> isFavorite({
    required String courseId,
    required int cardNumber,
  }) async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await localDb.query(
      'favorites',
      where: 'course_id = ? AND card_number = ?',
      whereArgs: [courseId, cardNumber],
    );
    return maps.isNotEmpty;
  }

  @override
  Future<List<Flashcard>> getFavoriteCards(String courseId) async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> favMaps = await localDb.query(
      'favorites',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'added_at DESC',
    );

    if (favMaps.isEmpty) return [];

    final dbPath = await _getCourseDatabasePath(courseId);
    if (!File(dbPath).existsSync()) {
      return [];
    }

    final courseDb = await databaseHelper.openCourseDatabase(dbPath);
    final List<Flashcard> favoritesList = [];

    for (final fav in favMaps) {
      final cardNum = fav['card_number'] as int;
      final List<Map<String, dynamic>> cardMaps = await courseDb.query(
        'cards',
        where: 'card_number = ?',
        whereArgs: [cardNum],
      );
      if (cardMaps.isNotEmpty) {
        final cardMap = cardMaps.first;
        final List<Map<String, dynamic>> progressMaps = await localDb.query(
          'client_progress',
          where: 'course_id = ? AND card_number = ?',
          whereArgs: [courseId, cardNum],
        );
        var progress = progressMaps.isNotEmpty
            ? CardProgressModel.fromMap(progressMaps.first)
            : CardProgressModel(
                id: '${courseId}_$cardNum',
                courseId: courseId,
                cardNumber: cardNum,
                currentBox: 1,
                lastReviewedAt: null,
                nextReviewDue: DateTime.now(),
                lastTrigger: null,
                isSynced: false,
                hasEnteredLeitner: false,
              );

        List<String>? optionsList;
        final optionsStr = cardMap['options'] as String?;
        if (optionsStr != null && optionsStr.isNotEmpty) {
          try {
            final parsed = jsonDecode(optionsStr);
            if (parsed is List) {
              optionsList = parsed.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        }

        favoritesList.add(
          Flashcard(
            id: cardMap['id'] as String,
            courseId: courseId,
            cardNumber: cardNum,
            questionText: cardMap['question_text'] as String,
            answerText: cardMap['answer_text'] as String,
            imageUrl: (cardMap['image_name'] ?? cardMap['image_url']) as String?,
            audioUrl: (cardMap['audio_name'] ?? cardMap['audio_url']) as String?,
            options: optionsList,
            progress: progress,
          ),
        );
      }
    }
    await courseDb.close();
    return favoritesList;
  }

  @override
  Future<void> submitReport({
    required String courseId,
    required int cardNumber,
    required String reportText,
  }) async {
    final payload = {
      'course_id': courseId,
      'card_number': cardNumber,
      'report_text': reportText,
    };
    await dioClient.dio.post('/courses/reports', data: payload);
  }

  @override
  Future<int> getGlobalDueCount() async {
    final localDb = await databaseHelper.localDatabase;
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final coursesDir = Directory(p.join(docDir.path, 'courses'));
      if (coursesDir.existsSync()) {
        final entities = coursesDir.listSync();
        for (final entity in entities) {
          if (entity is Directory) {
            final courseId = p.basename(entity.path);
            await checkForOverdueResets(courseId);
          }
        }
      }
    } catch (_) {}

    final List<Map<String, dynamic>> results = await localDb.rawQuery('''
      SELECT COUNT(*) as count FROM client_progress
      WHERE current_box >= 1 AND current_box <= 5 AND next_review_due <= ?
    ''', [nowUtc]);

    if (results.isEmpty) return 0;
    return Sqflite.firstIntValue(results) ?? 0;
  }

  @override
  Future<int> getGlobalFinishedCount() async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> results = await localDb.rawQuery('''
      SELECT COUNT(*) as count FROM client_progress
      WHERE current_box = 6
    ''');
    return Sqflite.firstIntValue(results) ?? 0;
  }

  @override
  Future<List<Flashcard>> getFinishedCards() async {
    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> progressMaps = await localDb.query(
      'client_progress',
      where: 'current_box = 6',
    );

    final List<Flashcard> finishedList = [];
    for (final map in progressMaps) {
      final courseId = map['course_id'] as String;
      final cardNum = map['card_number'] as int;
      final card = await getCardByNumber(courseId, cardNum);
      if (card != null) {
        finishedList.add(card);
      }
    }
    return finishedList;
  }

  @override
  Future<List<Flashcard>> getAllCardsForCourse(String courseId) async {
    final dbPath = await _getCourseDatabasePath(courseId);
    if (!File(dbPath).existsSync()) {
      return [];
    }

    final courseDb = await databaseHelper.openCourseDatabase(dbPath);
    final List<Map<String, dynamic>> cardMaps = await courseDb.query('cards', orderBy: 'card_number');
    await courseDb.close();

    final localDb = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> progressMaps = await localDb.query(
      'client_progress',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );

    final progressMap = {
      for (final map in progressMaps)
        map['card_number'] as int: CardProgressModel.fromMap(map)
    };

    final List<Flashcard> cards = [];
    final now = DateTime.now();

    for (final cardMap in cardMaps) {
      final cardNum = cardMap['card_number'] as int;
      var progress = progressMap[cardNum];

      if (progress == null) {
        progress = CardProgressModel(
          id: '${courseId}_$cardNum',
          courseId: courseId,
          cardNumber: cardNum,
          currentBox: 1,
          lastReviewedAt: null,
          nextReviewDue: now,
          lastTrigger: null,
          isSynced: false,
          hasEnteredLeitner: false,
        );
      }

      List<String>? optionsList;
      final optionsStr = cardMap['options'] as String?;
      if (optionsStr != null && optionsStr.isNotEmpty) {
        try {
          final parsed = jsonDecode(optionsStr);
          if (parsed is List) {
            optionsList = parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      cards.add(
        Flashcard(
          id: cardMap['id'] as String,
          courseId: courseId,
          cardNumber: cardNum,
          questionText: cardMap['question_text'] as String,
          answerText: cardMap['answer_text'] as String,
          imageUrl: (cardMap['image_name'] ?? cardMap['image_url']) as String?,
          audioUrl: (cardMap['audio_name'] ?? cardMap['audio_url']) as String?,
          options: optionsList,
          progress: progress,
        ),
      );
    }

    return cards;
  }
}
