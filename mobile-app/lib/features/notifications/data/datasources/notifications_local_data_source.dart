import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/features/notifications/data/models/banner_model.dart';
import 'package:mobile_app/features/notifications/data/models/announcement_model.dart';

abstract class NotificationsLocalDataSource {
  Future<void> cacheBanners(List<BannerModel> banners);
  Future<List<BannerModel>> getCachedBanners();
  Future<void> cacheAnnouncements(List<AnnouncementModel> announcements);
  Future<List<AnnouncementModel>> getCachedAnnouncements();
}

class NotificationsLocalDataSourceImpl implements NotificationsLocalDataSource {
  final DatabaseHelper databaseHelper;

  NotificationsLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> cacheBanners(List<BannerModel> banners) async {
    final db = await databaseHelper.localDatabase;
    await db.transaction((txn) async {
      await txn.delete('banners_cache');
      for (final banner in banners) {
        await txn.insert(
          'banners_cache',
          banner.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<BannerModel>> getCachedBanners() async {
    final db = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await db.query(
      'banners_cache',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'display_order',
    );
    return maps.map((map) => BannerModel.fromDbMap(map)).toList();
  }

  @override
  Future<void> cacheAnnouncements(List<AnnouncementModel> announcements) async {
    final db = await databaseHelper.localDatabase;
    await db.transaction((txn) async {
      await txn.delete('announcements_cache');
      for (final announcement in announcements) {
        await txn.insert(
          'announcements_cache',
          announcement.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<AnnouncementModel>> getCachedAnnouncements() async {
    final db = await databaseHelper.localDatabase;
    final List<Map<String, dynamic>> maps = await db.query(
      'announcements_cache',
      orderBy: 'published_at DESC',
    );
    return maps.map((map) => AnnouncementModel.fromDbMap(map)).toList();
  }
}
