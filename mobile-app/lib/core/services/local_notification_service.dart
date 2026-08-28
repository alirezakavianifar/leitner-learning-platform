import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:mobile_app/core/diagnostics/app_logger.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  LocalNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  static const String cardReviewChannelId = 'leitner_card_review_channel_v2';
  static const String cardReviewChannelName = 'Leitner Card Reviews';
  static const String cardReviewChannelDescription =
      'Notifications alerting you when cards are ready for review in your Leitner box.';

  static const int cardReviewNotificationId = 1001;
  static const int dailyReminderNotificationId = 2001;
  static const int testNotificationId = 9999;

  bool get isInitialized => _isInitialized;

  /// Configures timezone database and resolves the device's local timezone.
  void _configureLocalTimeZone() {
    try {
      tz.initializeTimeZones();
      final now = DateTime.now();
      final localOffset = now.timeZoneOffset;
      final localTzName = now.timeZoneName;

      // 1. Direct location match
      if (tz.timeZoneDatabase.locations.containsKey(localTzName)) {
        tz.setLocalLocation(tz.getLocation(localTzName));
        return;
      }

      // 2. Iran / Middle East common offsets
      if (localOffset.inMinutes == 210) {
        if (tz.timeZoneDatabase.locations.containsKey('Asia/Tehran')) {
          tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
          return;
        }
      } else if (localOffset.inMinutes == 240) {
        if (tz.timeZoneDatabase.locations.containsKey('Asia/Dubai')) {
          tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
          return;
        }
      }

      // 3. Search database for any location matching the device's current offset
      for (final entry in tz.timeZoneDatabase.locations.entries) {
        final tzNow = tz.TZDateTime.now(entry.value);
        if (tzNow.timeZoneOffset == localOffset) {
          tz.setLocalLocation(entry.value);
          return;
        }
      }
    } catch (e) {
      AppLogger().error('Error resolving local timezone: $e', e);
    }
  }

  /// Initializes timezone data and native local notification handlers.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _configureLocalTimeZone();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create Android Notification Channel with maximum importance for heads-up top-bar display
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            cardReviewChannelId,
            cardReviewChannelName,
            description: cardReviewChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
            enableLights: true,
          );
          await androidImpl.createNotificationChannel(channel);
        }
      }

      _isInitialized = true;
      AppLogger().info('LocalNotificationService successfully initialized.');
    } catch (e, stack) {
      AppLogger().error('Failed to initialize LocalNotificationService: $e', e, stack);
    }
  }

  /// Requests notification permission from user (Android 13+ and iOS).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          try {
            await androidImpl.requestExactAlarmsPermission();
          } catch (_) {}
          AppLogger().info('Android POST_NOTIFICATIONS permission result: $granted');
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      AppLogger().error('Error requesting notification permissions: $e', e);
    }
    return true;
  }

  void _onNotificationTap(NotificationResponse response) {
    AppLogger().info('Notification tapped with payload: ${response.payload}');
  }

  NotificationDetails _getNotificationDetails() {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      cardReviewChannelId,
      cardReviewChannelName,
      channelDescription: cardReviewChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      showWhen: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Immediately presents a notification in the top status bar.
  Future<void> showImmediateNotification({
    int id = testNotificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await init();

      final details = _getNotificationDetails();
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      AppLogger().info('Immediate notification displayed in top bar: id=$id, title=$title');
    } catch (e, stack) {
      AppLogger().error('Failed to show immediate notification: $e', e, stack);
    }
  }

  /// Schedules a one-time notification at a specific [scheduledDate].
  Future<void> scheduleNotification({
    int id = cardReviewNotificationId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await init();

      // Guard: scheduledDate must be in the future
      if (scheduledDate.isBefore(DateTime.now())) {
        return;
      }

      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      final details = _getNotificationDetails();

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {
        // Fallback to inexact scheduling if exact alarm permission is restricted on device
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }

      AppLogger().info(
        'Scheduled notification id=$id for $tzDateTime (UTC: ${scheduledDate.toUtc()})',
      );
    } catch (e, stack) {
      AppLogger().error('Failed to schedule notification: $e', e, stack);
    }
  }

  /// Schedules a recurring daily reminder at [hour] and [minute].
  Future<void> scheduleDailyReminder({
    int id = dailyReminderNotificationId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await init();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final details = _getNotificationDetails();

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } catch (_) {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      }

      AppLogger().info(
        'Scheduled daily reminder id=$id at $hour:$minute (next: $scheduledDate)',
      );
    } catch (e, stack) {
      AppLogger().error('Failed to schedule daily reminder: $e', e, stack);
    }
  }

  /// Cancels a specific scheduled notification by [id].
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
      AppLogger().info('Cancelled notification id=$id');
    } catch (e) {
      AppLogger().error('Failed to cancel notification id=$id: $e', e);
    }
  }

  /// Cancels all scheduled and active notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      AppLogger().info('Cancelled all notifications');
    } catch (e) {
      AppLogger().error('Failed to cancel all notifications: $e', e);
    }
  }
}
