import 'package:dio/dio.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/features/notifications/data/models/banner_model.dart';
import 'package:mobile_app/features/notifications/data/models/announcement_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<BannerModel>> getBanners();
  Future<List<AnnouncementModel>> getAnnouncements();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final DioClient dioClient;

  NotificationsRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<BannerModel>> getBanners() async {
    final response = await dioClient.dio.get('/banners');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => BannerModel.fromJson(json)).toList();
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }

  @override
  Future<List<AnnouncementModel>> getAnnouncements() async {
    final response = await dioClient.dio.get('/announcements');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => AnnouncementModel.fromJson(json)).toList();
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }
}
