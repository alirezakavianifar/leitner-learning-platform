import 'package:mobile_app/features/notifications/domain/entities/banner.dart';
import 'package:mobile_app/features/notifications/domain/entities/announcement.dart';

abstract class NotificationsRepository {
  Future<List<Banner>> getBanners({bool forceRefresh = false});
  Future<List<Announcement>> getAnnouncements({bool forceRefresh = false});
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<Set<String>> getReadAnnouncementIds();
  Future<void> syncNotifications();
}
