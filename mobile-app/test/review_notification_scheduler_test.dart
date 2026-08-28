import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/core/services/local_notification_service.dart';
import 'package:mobile_app/core/services/review_notification_scheduler.dart';

class FakeStorageService implements StorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> writeSecure(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> readSecure(String key) async {
    return _storage[key];
  }

  @override
  Future<void> deleteSecure(String key) async {
    _storage.remove(key);
  }
}

class FakeLocalNotificationService extends Fake implements LocalNotificationService {
  final List<Map<String, dynamic>> scheduledNotifications = [];
  final List<Map<String, dynamic>> immediateNotifications = [];
  final List<Map<String, dynamic>> scheduledDailyReminders = [];
  final List<int> cancelledNotificationIds = [];
  bool permissionsRequested = false;
  @override
  bool isInitialized = false;

  @override
  Future<void> init() async {
    isInitialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionsRequested = true;
    return true;
  }

  @override
  Future<void> scheduleNotification({
    int id = LocalNotificationService.cardReviewNotificationId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    scheduledNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'payload': payload,
    });
  }

  @override
  Future<void> scheduleDailyReminder({
    int id = LocalNotificationService.dailyReminderNotificationId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    scheduledDailyReminders.add({
      'id': id,
      'title': title,
      'body': body,
      'hour': hour,
      'minute': minute,
      'payload': payload,
    });
  }

  @override
  Future<void> showImmediateNotification({
    int id = LocalNotificationService.testNotificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    immediateNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
    });
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledNotificationIds.add(id);
    scheduledNotifications.removeWhere((item) => item['id'] == id);
    scheduledDailyReminders.removeWhere((item) => item['id'] == id);
  }

  @override
  Future<void> cancelAll() async {
    cancelledNotificationIds.addAll(
      scheduledNotifications.map((e) => e['id'] as int),
    );
    scheduledNotifications.clear();
    scheduledDailyReminders.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database localDb;
  late DatabaseHelper databaseHelper;
  late FakeStorageService storageService;
  late SharedPreferences sharedPreferences;
  late EventBus eventBus;
  late FakeLocalNotificationService notificationService;
  late ReviewNotificationScheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    storageService = FakeStorageService();
    databaseHelper = DatabaseHelper(storageService);
    eventBus = EventBus();
    notificationService = FakeLocalNotificationService();

    localDb = await databaseHelper.localDatabase;
    await localDb.delete('client_progress');

    scheduler = ReviewNotificationScheduler(
      localNotificationService: notificationService,
      databaseHelper: databaseHelper,
      sharedPreferences: sharedPreferences,
      eventBus: eventBus,
    );
  });

  tearDown(() async {
    scheduler.dispose();
    await databaseHelper.closeAll();
  });

  group('ReviewNotificationScheduler Tests', () {
    test('init() initializes notification service, schedules review and daily reminder', () async {
      await scheduler.init();

      expect(notificationService.isInitialized, isTrue);
      // Default daily reminder is enabled at 20:00
      expect(notificationService.scheduledDailyReminders.isNotEmpty, isTrue);
      expect(notificationService.scheduledDailyReminders.first['hour'], 20);
      expect(notificationService.scheduledDailyReminders.first['minute'], 0);
    });

    test('scheduleNextReviewNotification schedules earliest future due card in Boxes 2-5', () async {
      final now = DateTime.now().toUtc();
      final futureDue1 = now.add(const Duration(hours: 3));
      final futureDue2 = now.add(const Duration(hours: 8));

      // Insert card in Box 2 due in 3 hours
      await localDb.insert('client_progress', {
        'id': 'course_1_1',
        'course_id': 'course_1',
        'card_number': 1,
        'current_box': 2,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_due': futureDue1.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 0,
        'has_entered_leitner': 1,
      });

      // Insert card in Box 3 due in 8 hours
      await localDb.insert('client_progress', {
        'id': 'course_1_2',
        'course_id': 'course_1',
        'card_number': 2,
        'current_box': 3,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_due': futureDue2.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 0,
        'has_entered_leitner': 1,
      });

      await scheduler.scheduleNextReviewNotification();

      expect(notificationService.scheduledNotifications.isNotEmpty, isTrue);
      final scheduled = notificationService.scheduledNotifications.first;
      expect(scheduled['id'], LocalNotificationService.cardReviewNotificationId);

      final scheduledDateTime = scheduled['scheduledDate'] as DateTime;
      // Scheduled time should match the earliest due card (within 1 second precision)
      expect(
        scheduledDateTime.toUtc().difference(futureDue1).inSeconds.abs() <= 1,
        isTrue,
      );
    });

    test('scheduleNextReviewNotification cancels notification when no future due cards exist', () async {
      await scheduler.scheduleNextReviewNotification();

      expect(
        notificationService.cancelledNotificationIds,
        contains(LocalNotificationService.cardReviewNotificationId),
      );
    });

    test('scheduleNextReviewNotification cancels notification when notifications are disabled', () async {
      final now = DateTime.now().toUtc();
      await localDb.insert('client_progress', {
        'id': 'course_1_1',
        'course_id': 'course_1',
        'card_number': 1,
        'current_box': 2,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_due': now.add(const Duration(hours: 4)).toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 0,
        'has_entered_leitner': 1,
      });

      await scheduler.setNotificationsEnabled(false);

      expect(scheduler.areNotificationsEnabled, isFalse);
      expect(
        notificationService.cancelledNotificationIds,
        contains(LocalNotificationService.cardReviewNotificationId),
      );
    });

    test('EventBus CardReviewed automatically triggers notification rescheduling', () async {
      await scheduler.init();

      final now = DateTime.now().toUtc();
      final futureDue = now.add(const Duration(hours: 5));

      await localDb.insert('client_progress', {
        'id': 'course_1_10',
        'course_id': 'course_1',
        'card_number': 10,
        'current_box': 2,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_due': futureDue.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 0,
        'has_entered_leitner': 1,
      });

      notificationService.scheduledNotifications.clear();

      // Fire CardReviewed event
      eventBus.fire(CardReviewed(
        courseId: 'course_1',
        cardNumber: 10,
        box: 2,
        reviewedAt: DateTime.now(),
      ));

      // Allow microtasks to process stream event
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notificationService.scheduledNotifications.isNotEmpty, isTrue);
    });

    test('Daily reminder configuration update and cancellation', () async {
      await scheduler.init();

      // Change daily reminder time to 09:30
      await scheduler.setDailyReminderTime(9, 30);
      expect(scheduler.dailyReminderHour, 9);
      expect(scheduler.dailyReminderMinute, 30);

      final latestDaily = notificationService.scheduledDailyReminders.last;
      expect(latestDaily['hour'], 9);
      expect(latestDaily['minute'], 30);

      // Disable daily reminder
      await scheduler.setDailyReminderEnabled(false);
      expect(scheduler.isDailyReminderEnabled, isFalse);
      expect(
        notificationService.cancelledNotificationIds,
        contains(LocalNotificationService.dailyReminderNotificationId),
      );
    });

    test('sendTestNotification fires immediate notification and requests permissions', () async {
      await scheduler.sendTestNotification(isPersian: true);

      expect(notificationService.permissionsRequested, isTrue);
      expect(notificationService.immediateNotifications.isNotEmpty, isTrue);
      expect(
        notificationService.immediateNotifications.first['id'],
        LocalNotificationService.testNotificationId,
      );
    });

    test('checkDueAndNotifyNow notifies immediately if cards are currently due', () async {
      final now = DateTime.now().toUtc();
      final pastDue = now.subtract(const Duration(hours: 2));

      await localDb.insert('client_progress', {
        'id': 'course_1_5',
        'course_id': 'course_1',
        'card_number': 5,
        'current_box': 2,
        'last_reviewed_at': pastDue.toIso8601String(),
        'next_review_due': pastDue.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 0,
        'has_entered_leitner': 1,
      });

      await scheduler.checkDueAndNotifyNow();

      expect(notificationService.immediateNotifications.isNotEmpty, isTrue);
      expect(
        notificationService.immediateNotifications.first['id'],
        LocalNotificationService.cardReviewNotificationId,
      );
    });

    test('onAppBackgrounded triggers future scheduling and due notification', () async {
      final now = DateTime.now().toUtc();
      final pastDue = now.subtract(const Duration(hours: 1));

      await localDb.insert('client_progress', {
        'id': 'course_1_8',
        'course_id': 'course_1',
        'card_number': 8,
        'current_box': 3,
        'last_reviewed_at': pastDue.toIso8601String(),
        'next_review_due': pastDue.toIso8601String(),
        'last_trigger': 'REVIEW_CORRECT',
        'is_synced': 0,
        'has_entered_leitner': 1,
      });

      await scheduler.onAppBackgrounded();

      expect(notificationService.immediateNotifications.isNotEmpty, isTrue);
    });
  });
}
