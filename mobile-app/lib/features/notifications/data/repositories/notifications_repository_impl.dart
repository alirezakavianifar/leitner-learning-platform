import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/features/notifications/domain/entities/banner.dart' as entity;
import 'package:mobile_app/features/notifications/domain/entities/announcement.dart' as entity;
import 'package:mobile_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile_app/features/notifications/data/datasources/notifications_local_data_source.dart';
import 'package:mobile_app/features/notifications/data/datasources/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsLocalDataSource localDataSource;
  final NotificationsRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  final EventBus? eventBus;

  static const String _kLastSyncBannersKey = 'last_sync_banners';
  static const String _kLastSyncAnnouncementsKey = 'last_sync_announcements';
  static const String _kReadAnnouncementIdsKey = 'read_announcement_ids';

  NotificationsRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.sharedPreferences,
    this.eventBus,
  });

  @override
  Future<List<entity.Banner>> getBanners({bool forceRefresh = false}) async {
    final shouldSync = _shouldSyncBanners(forceRefresh);
    if (shouldSync) {
      try {
        final remoteBanners = await remoteDataSource.getBanners();
        await localDataSource.cacheBanners(remoteBanners);
        await _updateSyncTime(_kLastSyncBannersKey);
        return remoteBanners;
      } catch (e) {
        // Fallback to local cache in case of network failures
        return await localDataSource.getCachedBanners();
      }
    }
    return await localDataSource.getCachedBanners();
  }

  @override
  Future<List<entity.Announcement>> getAnnouncements({bool forceRefresh = false}) async {
    final shouldSync = _shouldSyncAnnouncements(forceRefresh);
    if (shouldSync) {
      try {
        final remoteAnnouncements = await remoteDataSource.getAnnouncements();
        await localDataSource.cacheAnnouncements(remoteAnnouncements);
        await _updateSyncTime(_kLastSyncAnnouncementsKey);

        final unreadCount = _calculateUnread(remoteAnnouncements);
        eventBus?.fire(AnnouncementsUpdated(
          unreadCount: unreadCount,
          totalCount: remoteAnnouncements.length,
        ));

        return remoteAnnouncements;
      } catch (e) {
        // Fallback to local cache in case of network failures
        final cached = await localDataSource.getCachedAnnouncements();
        final unreadCount = _calculateUnread(cached);
        eventBus?.fire(AnnouncementsUpdated(
          unreadCount: unreadCount,
          totalCount: cached.length,
        ));
        return cached;
      }
    }

    final cached = await localDataSource.getCachedAnnouncements();
    return cached;
  }

  @override
  Future<int> getUnreadCount() async {
    final cached = await localDataSource.getCachedAnnouncements();
    return _calculateUnread(cached);
  }

  @override
  Future<Set<String>> getReadAnnouncementIds() async {
    final list = sharedPreferences.getStringList(_kReadAnnouncementIdsKey) ?? [];
    return list.toSet();
  }

  @override
  Future<void> markAsRead(String id) async {
    final readSet = await getReadAnnouncementIds();
    if (!readSet.contains(id)) {
      readSet.add(id);
      await sharedPreferences.setStringList(_kReadAnnouncementIdsKey, readSet.toList());
      
      final cached = await localDataSource.getCachedAnnouncements();
      final unreadCount = _calculateUnread(cached);
      eventBus?.fire(AnnouncementsUpdated(
        unreadCount: unreadCount,
        totalCount: cached.length,
      ));
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final cached = await localDataSource.getCachedAnnouncements();
    final readSet = await getReadAnnouncementIds();
    for (final a in cached) {
      readSet.add(a.id);
    }
    await sharedPreferences.setStringList(_kReadAnnouncementIdsKey, readSet.toList());

    eventBus?.fire(AnnouncementsUpdated(
      unreadCount: 0,
      totalCount: cached.length,
    ));
  }

  @override
  Future<void> syncNotifications() async {
    await Future.wait([
      getBanners(forceRefresh: true),
      getAnnouncements(forceRefresh: true),
    ]);
  }

  int _calculateUnread(List<entity.Announcement> list) {
    final readSet = (sharedPreferences.getStringList(_kReadAnnouncementIdsKey) ?? []).toSet();
    return list.where((a) => !readSet.contains(a.id)).length;
  }

  bool _shouldSyncBanners(bool forceRefresh) {
    if (forceRefresh) return true;
    final lastSyncString = sharedPreferences.getString(_kLastSyncBannersKey);
    if (lastSyncString == null) return true;

    final lastSyncTime = DateTime.tryParse(lastSyncString);
    if (lastSyncTime == null) return true;

    final now = DateTime.now();
    return now.difference(lastSyncTime).inMinutes >= 15;
  }

  bool _shouldSyncAnnouncements(bool forceRefresh) {
    if (forceRefresh) return true;
    final lastSyncString = sharedPreferences.getString(_kLastSyncAnnouncementsKey);
    if (lastSyncString == null) return true;

    final lastSyncTime = DateTime.tryParse(lastSyncString);
    if (lastSyncTime == null) return true;

    final now = DateTime.now();
    // Allow refreshing announcements if more than 2 minutes have passed or explicitly requested
    return now.difference(lastSyncTime).inMinutes >= 2;
  }

  Future<void> _updateSyncTime(String key) async {
    final nowString = DateTime.now().toIso8601String();
    await sharedPreferences.setString(key, nowString);
  }
}

