import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/error/error_formatter.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/error/failures.dart';

void main() {
  group('AppErrorFormatter Persian Messaging Tests', () {
    test('Format NetworkFailure', () {
      const failure = NetworkFailure('No internet connection');
      final msg = AppErrorFormatter.toPersianMessage(failure);
      expect(msg, contains('ارتباط با سرور برقرار نشد'));
      expect(msg, contains('اینترنت'));
    });

    test('Format ServerFailure with Error Code CAPTCHA_INVALID', () {
      const failure = ServerFailure('Invalid captcha', errorCode: 'CAPTCHA_INVALID');
      final msg = AppErrorFormatter.toPersianMessage(failure);
      expect(msg, contains('کد امنیتی'));
      expect(msg, contains('کپچا'));
    });

    test('Format ServerFailure with Error Code OTP_EXPIRED', () {
      const failure = ServerFailure('OTP expired', errorCode: 'OTP_EXPIRED');
      final msg = AppErrorFormatter.toPersianMessage(failure);
      expect(msg, contains('کد تایید ۵ رقمی منقضی شده است'));
    });

    test('Format ServerFailure with Error Code CHECKSUM_MISMATCH', () {
      const failure = ServerFailure('Checksum error', errorCode: 'CHECKSUM_MISMATCH');
      final msg = AppErrorFormatter.toPersianMessage(failure);
      expect(msg, contains('تایید اصالت فایل دوره'));
    });

    test('Format DioException Timeout', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api'),
        type: DioExceptionType.connectionTimeout,
      );
      final msg = AppErrorFormatter.toPersianMessage(dioErr);
      expect(msg, contains('ارتباط با سرور برقرار نشد'));
    });

    test('Format DioException 429 Rate Limit', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api'),
        response: Response(
          requestOptions: RequestOptions(path: '/api'),
          statusCode: 429,
        ),
      );
      final msg = AppErrorFormatter.toPersianMessage(dioErr);
      expect(msg, contains('تعداد درخواست‌های شما بیش از حد مجاز است'));
    });

    test('Format DioException 500 Server Error', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api'),
        response: Response(
          requestOptions: RequestOptions(path: '/api'),
          statusCode: 500,
        ),
      );
      final msg = AppErrorFormatter.toPersianMessage(dioErr);
      expect(msg, contains('سرور در حال حاضر پاسخگو نیست'));
    });

    test('Format backup exception', () {
      final exc = Exception('Incorrect password or corrupted backup file.');
      final msg = AppErrorFormatter.toPersianMessage(exc);
      expect(msg, contains('رمز عبور وارد شده'));
      expect(msg, contains('آسیب دیده'));
    });

    test('Format image picker failure string', () {
      final msg = AppErrorFormatter.toPersianMessage('Failed to pick image: user cancelled');
      expect(msg, contains('تصویر'));
      expect(msg, contains('گالری'));
    });
  });

  group('AppErrorFormatter English Messaging Tests', () {
    test('Format NetworkFailure in English', () {
      const failure = NetworkFailure('No internet connection');
      final msg = AppErrorFormatter.toEnglishMessage(failure);
      expect(msg, contains('Could not connect to the server'));
    });

    test('Format CAPTCHA_INVALID in English', () {
      const failure = ServerFailure('Invalid captcha', errorCode: 'CAPTCHA_INVALID');
      final msg = AppErrorFormatter.toEnglishMessage(failure, errorCode: failure.errorCode);
      expect(msg, contains('Invalid CAPTCHA answer'));
    });

    test('Format OTP_EXPIRED in English', () {
      const failure = ServerFailure('OTP expired', errorCode: 'OTP_EXPIRED');
      final msg = AppErrorFormatter.toEnglishMessage(failure, errorCode: failure.errorCode);
      expect(msg, contains('Verification code expired'));
    });
  });
}
