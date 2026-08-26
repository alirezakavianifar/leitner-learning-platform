import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
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
  late EventBus eventBus;
  late NotificationsRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    eventBus = EventBus();

    localDataSource = FakeLocalDataSource();
    remoteDataSource = FakeRemoteDataSource();

    repository = NotificationsRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      sharedPreferences: sharedPreferences,
      eventBus: eventBus,
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

      // Verify second request does NOT call remote if within TTL
      final cachedBanners = await repository.getBanners();
      expect(cachedBanners.length, 2);
      expect(remoteDataSource.callCountBanners, 1);
    });

    test('Should call remote if forceRefresh is true', () async {
      await repository.getBanners();
      expect(remoteDataSource.callCountBanners, 1);

      await repository.getBanners(forceRefresh: true);
      expect(remoteDataSource.callCountBanners, 2);
    });

    test('Should fall back to local cache if remote calls fail (offline mode)', () async {
      // First, get remote and cache
      await repository.getAnnouncements(forceRefresh: true);
      expect(remoteDataSource.callCountAnnouncements, 1);
      expect(localDataSource.announcements.length, 2);

      // Now set remote to throw error, and force refresh
      remoteDataSource.throwError = true;
      final result = await repository.getAnnouncements(forceRefresh: true);
      
      // Should fall back to local cached announcements
      expect(result.length, 2);
      expect(remoteDataSource.callCountAnnouncements, 2);
    });

    test('Should track unread announcements and mark as read', () async {
      DomainEvent? lastFiredEvent;
      eventBus.on<DomainEvent>().listen((event) {
        lastFiredEvent = event;
      });

      // Initially fetch announcements
      final announcements = await repository.getAnnouncements(forceRefresh: true);
      expect(announcements.length, 2);

      // Both should be unread initially
      int unread = await repository.getUnreadCount();
      expect(unread, 2);
      expect(lastFiredEvent is AnnouncementsUpdated, isTrue);
      expect((lastFiredEvent as AnnouncementsUpdated).unreadCount, 2);

      // Mark a1 as read
      await repository.markAsRead('a1');
      unread = await repository.getUnreadCount();
      expect(unread, 1);
      expect((lastFiredEvent as AnnouncementsUpdated).unreadCount, 1);

      final readIds = await repository.getReadAnnouncementIds();
      expect(readIds.contains('a1'), isTrue);
      expect(readIds.contains('a2'), isFalse);

      // Mark all as read
      await repository.markAllAsRead();
      unread = await repository.getUnreadCount();
      expect(unread, 0);
      expect((lastFiredEvent as AnnouncementsUpdated).unreadCount, 0);
    });
  });
}

