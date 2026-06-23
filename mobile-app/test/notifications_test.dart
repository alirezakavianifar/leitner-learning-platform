import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/notifications/data/models/banner_model.dart';
import 'package:mobile_app/features/notifications/data/models/announcement_model.dart';
import 'package:mobile_app/features/notifications/data/datasources/notifications_local_data_source.dart';
import 'package:mobile_app/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:mobile_app/features/notifications/data/repositories/notifications_repository_impl.dart';

class FakeLocalDataSource implements NotificationsLocalDataSource {
  List<BannerModel> banners = [];
  List<AnnouncementModel> announcements = [];

  @override
  Future<void> cacheBanners(List<BannerModel> list) async {
    banners = list;
  }

  @override
  Future<List<BannerModel>> getCachedBanners() async {
    return banners.where((b) => b.isActive).toList();
  }

  @override
  Future<void> cacheAnnouncements(List<AnnouncementModel> list) async {
    announcements = list;
  }

  @override
  Future<List<AnnouncementModel>> getCachedAnnouncements() async {
    return announcements;
  }
}

class FakeRemoteDataSource implements NotificationsRemoteDataSource {
  List<BannerModel> banners = [];
  List<AnnouncementModel> announcements = [];
  bool throwError = false;
  int callCountBanners = 0;
  int callCountAnnouncements = 0;

  @override
  Future<List<BannerModel>> getBanners() async {
    callCountBanners++;
    if (throwError) throw Exception('Network error');
    return banners;
  }

  @override
  Future<List<AnnouncementModel>> getAnnouncements() async {
    callCountAnnouncements++;
    if (throwError) throw Exception('Network error');
    return announcements;
  }
}

void main() {
  late FakeLocalDataSource localDataSource;
  late FakeRemoteDataSource remoteDataSource;
  late SharedPreferences sharedPreferences;
  late NotificationsRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    localDataSource = FakeLocalDataSource();
    remoteDataSource = FakeRemoteDataSource();

    repository = NotificationsRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      sharedPreferences: sharedPreferences,
    );

    // Initial dummy data
    remoteDataSource.banners = [
      const BannerModel(id: '1', imageUrl: 'url1', displayOrder: 1),
      const BannerModel(id: '2', imageUrl: 'url2', displayOrder: 2),
    ];
    remoteDataSource.announcements = [
      AnnouncementModel(id: 'a1', title: 'T1', content: 'C1', publishedAt: DateTime.parse('2026-06-20T00:00:00Z')),
      AnnouncementModel(id: 'a2', title: 'T2', content: 'C2', publishedAt: DateTime.parse('2026-06-21T00:00:00Z')),
    ];
  });

  group('Notifications Repository Tests', () {
    test('Should sync with remote on first request and cache locally', () async {
      final banners = await repository.getBanners();
      expect(banners.length, 2);
      expect(remoteDataSource.callCountBanners, 1);
      expect(localDataSource.banners.length, 2);

      // Verify second request does NOT call remote if less than 24 hours elapsed
      final cachedBanners = await repository.getBanners();
      expect(cachedBanners.length, 2);
      expect(remoteDataSource.callCountBanners, 1); // call count remains 1
    });

    test('Should call remote if forceRefresh is true', () async {
      await repository.getBanners();
      expect(remoteDataSource.callCountBanners, 1);

      await repository.getBanners(forceRefresh: true);
      expect(remoteDataSource.callCountBanners, 2);
    });

    test('Should call remote if last sync is older than 24 hours', () async {
      await repository.getBanners();
      expect(remoteDataSource.callCountBanners, 1);

      // Set last sync to 25 hours ago
      final oldTime = DateTime.now().subtract(const Duration(hours: 25)).toIso8601String();
      await sharedPreferences.setString('last_sync_notifications_banners', oldTime);

      await repository.getBanners();
      expect(remoteDataSource.callCountBanners, 2);
    });

    test('Should fall back to local cache if remote calls fail (offline mode)', () async {
      // First, get remote and cache
      await repository.getAnnouncements();
      expect(remoteDataSource.callCountAnnouncements, 1);
      expect(localDataSource.announcements.length, 2);

      // Now set remote to throw error, and force refresh
      remoteDataSource.throwError = true;
      final result = await repository.getAnnouncements(forceRefresh: true);
      
      // Should fall back to local cached announcements
      expect(result.length, 2);
      expect(remoteDataSource.callCountAnnouncements, 2);
    });
  });
}
