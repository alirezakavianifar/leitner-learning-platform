import 'package:dio/dio.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/features/courses/data/models/course_model.dart';

abstract class CoursesRemoteDataSource {
  Future<List<CourseModel>> getCourses();
  Future<Map<String, dynamic>> getDownloadToken(String courseId);
}

class CoursesRemoteDataSourceImpl implements CoursesRemoteDataSource {
  final DioClient dioClient;

  CoursesRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<CourseModel>> getCourses() async {
    final response = await dioClient.dio.get('/courses');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => CourseModel.fromJson(json)).toList();
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getDownloadToken(String courseId) async {
    final response = await dioClient.dio.post('/courses/$courseId/download-token');
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }
}
