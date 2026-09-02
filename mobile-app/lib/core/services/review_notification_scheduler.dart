import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/core/diagnostics/app_logger.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';
import 'local_notification_service.dart';

class ReviewNotificationScheduler {
  final LocalNotificationService localNotificationService;
  final DatabaseHelper databaseHelper;
  final SharedPreferences sharedPreferences;
  final EventBus eventBus;

  StreamSubscription<DomainEvent>? _eventSubscription;
  bool _isInitialized = false;

  static const String keyNotificationsEnabled = 'notifications_card_reviews_enabled';
  static const String keyDailyReminderEnabled = 'notifications_daily_reminder_enabled';
  static const String keyDailyReminderHour = 'notifications_daily_reminder_hour';
  static const String keyDailyReminderMinute = 'notifications_daily_reminder_minute';
  static const String keyDailyReminderIsCustomized = 'notifications_daily_reminder_is_customized';

  ReviewNotificationScheduler({
    required this.localNotificationService,
    required this.databaseHelper,
    required this.sharedPreferences,
    required this.eventBus,
  });

  /// Initializes the scheduler, sets up event listeners, and schedules pending notifications.
  Future<void> init() async {
    if (_isInitialized) return;

    await localNotificationService.init();

    // Listen to domain events that modify Leitner box schedules
    _eventSubscription = eventBus.on<DomainEvent>().listen((event) {
      if (event is CardReviewed ||
          event is CardFinished ||
          event is DueDateOverdueReset ||
          event is LeitnerProgressReset ||
          event is CourseDownloaded) {
        scheduleNextReviewNotification();
      }
    });

    _isInitialized = true;
    // Proactively request notification permissions from the OS on startup/first launch
    if (areNotificationsEnabled) {
      await localNotificationService.requestPermissions();
    }

    // Schedule notifications on boot
    await scheduleNextReviewNotification();
    await updateDailyReminder();
  }

  /// Whether card review notifications are enabled by the user.
  bool get areNotificationsEnabled =>
      sharedPreferences.getBool(keyNotificationsEnabled) ?? true;

  /// Whether daily study reminder notifications are enabled.
  bool get isDailyReminderEnabled =>
      sharedPreferences.getBool(keyDailyReminderEnabled) ?? true;

  /// Whether the user has explicitly selected a custom daily reminder time in Settings.
  bool get isDailyReminderCustomized =>
      sharedPreferences.getBool(keyDailyReminderIsCustomized) ?? false;

  /// Daily reminder hour (0..23, default 9 for 9:00 AM).
  int get dailyReminderHour =>
      sharedPreferences.getInt(keyDailyReminderHour) ?? 9;

  /// Daily reminder minute (0..59, default 0).
  int get dailyReminderMinute =>
      sharedPreferences.getInt(keyDailyReminderMinute) ?? 0;

  /// Sets whether review notifications are enabled.
  Future<void> setNotificationsEnabled(bool enabled) async {
    await sharedPreferences.setBool(keyNotificationsEnabled, enabled);
    if (enabled) {
      await localNotificationService.requestPermissions();
      await scheduleNextReviewNotification();
      await updateDailyReminder();
    } else {
      await localNotificationService.cancelNotification(
        LocalNotificationService.cardReviewNotificationId,
      );
      await localNotificationService.cancelNotification(
        LocalNotificationService.dailyReminderNotificationId,
      );
    }
  }

  /// Sets whether daily study reminders are enabled.
  Future<void> setDailyReminderEnabled(bool enabled) async {
    await sharedPreferences.setBool(keyDailyReminderEnabled, enabled);
    await updateDailyReminder();
  }

  /// Sets daily study reminder time customized by the user.
  Future<void> setDailyReminderTime(int hour, int minute) async {
    await sharedPreferences.setInt(keyDailyReminderHour, hour);
    await sharedPreferences.setInt(keyDailyReminderMinute, minute);
    await sharedPreferences.setBool(keyDailyReminderIsCustomized, true);
    await updateDailyReminder();
  }

  /// Resets daily reminder time to system/remote default.
  Future<void> resetDailyReminderToDefault({int defaultHour = 9, int defaultMinute = 0}) async {
    await sharedPreferences.setInt(keyDailyReminderHour, defaultHour);
    await sharedPreferences.setInt(keyDailyReminderMinute, defaultMinute);
    await sharedPreferences.setBool(keyDailyReminderIsCustomized, false);
    await updateDailyReminder();
  }

  /// Synchronizes daily study reminder with remote config from the server.
  /// If user hasn't explicitly customized their reminder time, applies the remote admin schedule.
  Future<void> syncWithRemoteConfig(RemoteConfig config) async {
    if (!isDailyReminderCustomized) {
      await sharedPreferences.setInt(keyDailyReminderHour, config.dailyReminderHour);
      await sharedPreferences.setInt(keyDailyReminderMinute, config.dailyReminderMinute);
      if (!sharedPreferences.containsKey(keyDailyReminderEnabled)) {
        await sharedPreferences.setBool(keyDailyReminderEnabled, config.enableDailyReminder);
      }
      await updateDailyReminder();
      AppLogger().info(
        'Synced daily reminder with remote config: ${config.dailyReminderHour}:${config.dailyReminderMinute.toString().padLeft(2, '0')} (enabled: ${config.enableDailyReminder})',
      );
    } else {
      AppLogger().info(
        'Skipping remote reminder sync because user customized their reminder time ($dailyReminderHour:$dailyReminderMinute).',
      );
    }
  }

  /// Handles app lifecycle transition when user backgrounds or leaves the app.
  Future<void> onAppBackgrounded() async {
    if (!areNotificationsEnabled) return;
    await scheduleNextReviewNotification();
    await checkDueAndNotifyNow();
  }

  /// Queries the local progress database and schedules a notification for the earliest upcoming review.
  Future<void> scheduleNextReviewNotification() async {
    if (!areNotificationsEnabled) {
      await localNotificationService.cancelNotification(
        LocalNotificationService.cardReviewNotificationId,
      );
      return;
    }

    try {
      final localDb = await databaseHelper.localDatabase;
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Find the earliest next_review_due in the future across active Leitner boxes (2-5)
      final List<Map<String, dynamic>> results = await localDb.rawQuery('''
        SELECT MIN(next_review_due) as earliest_due, COUNT(*) as count
        FROM client_progress
        WHERE current_box >= 2 AND current_box <= 5 AND next_review_due > ?
      ''', [nowUtc]);

      if (results.isNotEmpty && results.first['earliest_due'] != null) {
        final earliestDueStr = results.first['earliest_due'] as String;
        final earliestDueUtc = DateTime.parse(earliestDueStr).toUtc();
        final earliestDueLocal = earliestDueUtc.toLocal();

        final isFa = (sharedPreferences.getString('selected_locale') ?? 'fa') == 'fa';
        final title = isFa ? 'زمان مرور کارت‌های لایتنر! 📚' : 'Time for Leitner Review! 📚';
        final body = isFa
            ? 'کارت‌هایی در جعبه لایتنر شما آماده مرور هستند. برای شروع کلیک کنید.'
            : 'You have flashcards ready to review in your Leitner box. Tap to start.';

        await localNotificationService.scheduleNotification(
          id: LocalNotificationService.cardReviewNotificationId,
          title: title,
          body: body,
          scheduledDate: earliestDueLocal,
          payload: 'leitner_review_scheduled',
        );
        AppLogger().info('Next review notification scheduled for: $earliestDueLocal');
      } else {
        // No future cards scheduled
        await localNotificationService.cancelNotification(
          LocalNotificationService.cardReviewNotificationId,
        );
      }
    } catch (e, stack) {
      AppLogger().error('Failed to schedule next review notification: $e', e, stack);
    }
  }

  /// Updates or cancels the recurring daily study reminder.
  Future<void> updateDailyReminder() async {
    if (!isDailyReminderEnabled || !areNotificationsEnabled) {
      await localNotificationService.cancelNotification(
        LocalNotificationService.dailyReminderNotificationId,
      );
      return;
    }

    final isFa = (sharedPreferences.getString('selected_locale') ?? 'fa') == 'fa';
    final title = isFa ? 'یادآوری مطالعه روزانه 🎯' : 'Daily Study Reminder 🎯';
    final body = isFa
        ? 'مرور کارت‌های امروز جعبه لایتنر خود را فراموش نکنید!'
        : "Don't forget to review your Leitner flashcards today!";

    await localNotificationService.scheduleDailyReminder(
      id: LocalNotificationService.dailyReminderNotificationId,
      title: title,
      body: body,
      hour: dailyReminderHour,
      minute: dailyReminderMinute,
      payload: 'daily_leitner_reminder',
    );
  }

  /// Checks if any cards are due right now, and if so, shows an immediate status bar alert.
  Future<void> checkDueAndNotifyNow() async {
    if (!areNotificationsEnabled) return;

    try {
      final localDb = await databaseHelper.localDatabase;
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      final List<Map<String, dynamic>> results = await localDb.rawQuery('''
        SELECT COUNT(*) as count FROM client_progress
        WHERE current_box >= 2 AND current_box <= 5 AND next_review_due <= ?
      ''', [nowUtc]);

      final dueCount = results.isNotEmpty ? (results.first['count'] as int? ?? 0) : 0;
      if (dueCount > 0) {
        final isFa = (sharedPreferences.getString('selected_locale') ?? 'fa') == 'fa';
        final title = isFa ? 'کارت‌های آماده مرور دارید! 🔔' : 'Cards Ready for Review! 🔔';
        final body = isFa
            ? 'شما $dueCount کارت در انتظار مرور در جعبه لایتنر دارید.'
            : 'You have $dueCount flashcards waiting to be reviewed.';

        await localNotificationService.showImmediateNotification(
          id: LocalNotificationService.cardReviewNotificationId,
          title: title,
          body: body,
          payload: 'leitner_due_now',
        );
      } else {
        // Proactively clear any stale notification from the status bar if no cards are due
        await localNotificationService.cancelNotification(
          LocalNotificationService.cardReviewNotificationId,
        );
      }
    } catch (e) {
      AppLogger().error('Failed to check and notify due cards: $e', e);
    }
  }

  /// Sends a sample notification immediately to test the device's top notification bar.
  Future<void> sendTestNotification({bool isPersian = true}) async {
    await localNotificationService.requestPermissions();
    final title = isPersian ? 'آزمایش اعلان لایتنر 🔔' : 'Leitner Notification Test 🔔';
    final body = isPersian
        ? 'اعلان نوار بالای گوشی برای یادآوری مرور کارت‌ها فعال است.'
        : 'Top notification bar alert is working for card review reminders.';

    await localNotificationService.showImmediateNotification(
      id: LocalNotificationService.testNotificationId,
      title: title,
      body: body,
      payload: 'test_notification',
    );
  }

  void dispose() {
    _eventSubscription?.cancel();
  }
}
