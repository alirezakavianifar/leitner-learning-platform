import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/notifications/domain/entities/banner.dart' as entity;
import 'package:mobile_app/features/notifications/domain/entities/announcement.dart' as entity;
import 'package:mobile_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile_app/features/notifications/data/datasources/notifications_local_data_source.dart';
import 'package:mobile_app/features/notifications/data/datasources/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsLocalDataSource localDataSource;
  final NotificationsRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;

  static const String _kLastSyncTimeKey = 'last_sync_notifications_banners';

  NotificationsRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.sharedPreferences,
  });

  @override
  Future<List<entity.Banner>> getBanners({bool forceRefresh = false}) async {
    final shouldSync = await _shouldSync(forceRefresh);
    if (shouldSync) {
      try {
        final remoteBanners = await remoteDataSource.getBanners();
        await localDataSource.cacheBanners(remoteBanners);
        await _updateSyncTime();
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
    final shouldSync = await _shouldSync(forceRefresh);
    if (shouldSync) {
      try {
        final remoteAnnouncements = await remoteDataSource.getAnnouncements();
        await localDataSource.cacheAnnouncements(remoteAnnouncements);
        await _updateSyncTime();
        return remoteAnnouncements;
      } catch (e) {
        // Fallback to local cache in case of network failures
        return await localDataSource.getCachedAnnouncements();
      }
    }
    return await localDataSource.getCachedAnnouncements();
  }

  Future<bool> _shouldSync(bool forceRefresh) async {
    if (forceRefresh) return true;
    final lastSyncString = sharedPreferences.getString(_kLastSyncTimeKey);
    if (lastSyncString == null) return true;

    final lastSyncTime = DateTime.parse(lastSyncString);
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime);
    
    // Sync approximately once every 24 hours
    return difference.inHours >= 24;
  }

  Future<void> _updateSyncTime() async {
    final nowString = DateTime.now().toIso8601String();
    await sharedPreferences.setString(_kLastSyncTimeKey, nowString);
  }
}
