import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<(String captchaId, String imageBase64)> getCaptcha();
  Future<bool> requestOtp({
    required String mobileNumber,
    required String captchaId,
    required String captchaAnswer,
  });
  Future<(String token, String refreshToken, String userStatus)> verifyOtp({
    required String mobileNumber,
    required String otpCode,
  });
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile({
    required String username,
    String? interests,
    String? educationalField,
    String? educationalLevel,
  });
  Future<String> uploadAvatar(File file);
  Future<void> deleteAvatar();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<(String captchaId, String imageBase64)> getCaptcha() async {
    try {
      final response = await dio.get('/auth/captcha');
      if (response.statusCode == 200) {
        final data = response.data;
        return (data['captcha_id'] as String, data['image_base64'] as String);
      } else {
        throw ServerException('Failed to load CAPTCHA');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<bool> requestOtp({
    required String mobileNumber,
    required String captchaId,
    required String captchaAnswer,
  }) async {
    try {
      final response = await dio.post('/auth/otp/request', data: {
        'mobile_number': mobileNumber,
        'captcha_id': captchaId,
        'captcha_answer': captchaAnswer,
      });
      if (response.statusCode == 200) {
        return response.data['success'] as bool;
      } else {
        throw ServerException('Failed to request OTP');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<(String token, String refreshToken, String userStatus)> verifyOtp({
    required String mobileNumber,
    required String otpCode,
  }) async {
    try {
      final response = await dio.post('/auth/otp/verify', data: {
        'mobile_number': mobileNumber,
        'otp_code': otpCode,
      });
      if (response.statusCode == 200) {
        final data = response.data;
        return (
          data['token'] as String,
          data['refresh_token'] as String,
          data['user_status'] as String,
        );
      } else {
        throw ServerException('Failed to verify OTP');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await dio.get('/user/profile');
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to fetch user profile');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String username,
    String? interests,
    String? educationalField,
    String? educationalLevel,
  }) async {
    try {
      final response = await dio.put('/user/profile', data: {
        'username': username,
        'interests': interests,
        'educational_field': educationalField,
        'educational_level': educationalLevel,
      });
      if (response.statusCode == 200) {
        final data = response.data;
        return UserModel.fromJson(data['profile']);
      } else {
        throw ServerException('Failed to update user profile');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<String> uploadAvatar(File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await dio.post('/user/avatar', data: formData);
      if (response.statusCode == 200 && response.data != null) {
        return response.data['profile_picture_url'] as String;
      } else {
        throw ServerException('Failed to upload avatar');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  @override
  Future<void> deleteAvatar() async {
    try {
      final response = await dio.delete('/user/avatar');
      if (response.statusCode != 200) {
        throw ServerException('Failed to delete avatar');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Exception _handleDioException(DioException e) {
    if (e.response != null) {
      if (e.response?.data is Map) {
        final data = e.response?.data as Map;
        final message = data['message'] ?? 'خطایی در ارتباط با سرور رخ داد';
        final errorCode = data['error_code'] ?? data['errorCode'] ?? 'SERVER_ERROR';
        return ServerException(message.toString(), errorCode: errorCode.toString());
      }
      if (e.response?.statusCode == 404) {
        return const ServerException('سرویس یا منبع درخواستی روی سرور یافت نشد.', errorCode: 'NOT_FOUND');
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        return const ServerException('سرور در حال حاضر پاسخگو نیست.', errorCode: 'INTERNAL_SERVER_ERROR');
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException('ارتباط با اینترنت یا سرور برقرار نشد.');
    }
    return const ServerException('خطا در برقراری ارتباط با سرور.');
  }
}
