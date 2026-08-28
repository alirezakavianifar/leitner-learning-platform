import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

/// Centralized utility to map errors, exceptions, Dio error types, and backend status codes
/// into clear, polite, and highly informative messages with actionable hints for both Persian and English.
class AppErrorFormatter {
  /// Format error considering current AppLocalizations if context is available.
  /// If locale is Persian ('fa'), returns rich Persian error message.
  /// If locale is English ('en') or other, returns clean English error message.
  static String formatError(dynamic error, {BuildContext? context, String? errorCode}) {
    if (context != null) {
      final loc = AppLocalizations.of(context);
      if (loc.locale.languageCode != 'fa') {
        return toEnglishMessage(error, errorCode: errorCode);
      }
    }
    return toPersianMessage(error, errorCode: errorCode);
  }

  /// Returns a user-friendly Persian error message based on the error instance or code.
  static String toPersianMessage(dynamic error, {String? errorCode}) {
    // 1. Direct Error Code checks (if provided)
    if (errorCode != null && errorCode.isNotEmpty) {
      final translatedCode = _mapErrorCodeToPersian(errorCode);
      if (translatedCode != null) {
        return translatedCode;
      }
    }

    // 2. Specific Failure instances
    if (error is ServerFailure) {
      if (error.errorCode != null) {
        final translatedCode = _mapErrorCodeToPersian(error.errorCode!);
        if (translatedCode != null) return translatedCode;
      }
      return _translateStringMessage(error.message);
    }

    if (error is NetworkFailure) {
      return 'ارتباط با سرور برقرار نشد. لطفاً اتصال اینترنت خود را بررسی کرده و مجدداً تلاش کنید.';
    }

    if (error is CacheFailure) {
      return _translateStringMessage(error.message);
    }

    if (error is Failure) {
      return _translateStringMessage(error.message);
    }

    // 3. Specific Exception instances
    if (error is ServerException) {
      if (error.errorCode != null) {
        final translatedCode = _mapErrorCodeToPersian(error.errorCode!);
        if (translatedCode != null) return translatedCode;
      }
      return _translateStringMessage(error.message);
    }

    if (error is NetworkException) {
      return 'ارتباط با سرور برقرار نشد. لطفاً اتصال اینترنت خود را بررسی کرده و مجدداً تلاش کنید.';
    }

    if (error is CacheException) {
      return _translateStringMessage(error.message);
    }

    // 4. DioException (HTTP / Network level errors)
    if (error is DioException) {
      return _mapDioExceptionToPersian(error);
    }

    // 5. String message inspection
    if (error is String) {
      return _translateStringMessage(error);
    }

    // 6. Generic Exception / Object fallback
    if (error != null) {
      final strMsg = error.toString();
      return _translateStringMessage(strMsg);
    }

    return 'خطای غیرمنتظره‌ای رخ داده است. لطفاً چند دقیقه دیگر دوباره تلاش کنید.';
  }

  /// Returns a user-friendly English error message based on the error instance or code.
  static String toEnglishMessage(dynamic error, {String? errorCode}) {
    if (errorCode != null && errorCode.isNotEmpty) {
      final translatedCode = _mapErrorCodeToEnglish(errorCode);
      if (translatedCode != null) {
        return translatedCode;
      }
    }

    if (error is ServerFailure) {
      if (error.errorCode != null) {
        final translatedCode = _mapErrorCodeToEnglish(error.errorCode!);
        if (translatedCode != null) return translatedCode;
      }
      return error.message;
    }

    if (error is NetworkFailure) {
      return 'Could not connect to the server. Please check your internet connection.';
    }

    if (error is CacheFailure) {
      return error.message;
    }

    if (error is Failure) {
      return error.message;
    }

    if (error is ServerException) {
      if (error.errorCode != null) {
        final translatedCode = _mapErrorCodeToEnglish(error.errorCode!);
        if (translatedCode != null) return translatedCode;
      }
      return error.message;
    }

    if (error is NetworkException) {
      return 'Could not connect to the server. Please check your internet connection.';
    }

    if (error is CacheException) {
      return error.message;
    }

    if (error is DioException) {
      return _mapDioExceptionToEnglish(error);
    }

    if (error is String) {
      return error;
    }

    if (error != null) {
      return error.toString();
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Map backend error codes to descriptive Persian messages
  static String? _mapErrorCodeToPersian(String code) {
    final cleanCode = code.trim().toUpperCase();
    switch (cleanCode) {
      case 'CAPTCHA_INVALID':
      case 'INVALID_CAPTCHA':
        return 'کد امنیتی (کپچا) اشتباه وارد شده یا منقضی شده است. لطفاً کد جدید را وارد کنید.';
      case 'OTP_EXPIRED':
        return 'کد تایید ۵ رقمی منقضی شده است. لطفاً کد جدید درخواست کنید.';
      case 'INVALID_OTP':
      case 'OTP_INVALID':
        return 'کد تایید ۵ رقمی وارد شده اشتباه است. لطفاً کد را به دقت بررسی کنید.';
      case 'TOO_MANY_REQUESTS':
      case 'RATE_LIMIT_EXCEEDED':
        return 'تعداد درخواست‌های شما بیش از حد مجاز است. لطفاً چند دقیقه صبر کرده و دوباره تلاش کنید.';
      case 'USER_NOT_FOUND':
        return 'حساب کاربری با این مشخصات یافت نشد. لطفاً شماره موبایل را بررسی کنید.';
      case 'USER_BLOCKED':
        return 'حساب کاربری شما مسدود شده است. لطفاً با پشتیبانی تماس بگیرید.';
      case 'TERMS_NOT_ACCEPTED':
        return 'جهت استفاده از خدمات سامانه، پذیرش قوانین و مقررات الزامی است.';
      case 'CHECKSUM_MISMATCH':
        return 'تایید اصالت فایل دوره با خطا مواجه شد. ممکن است فایل دانلود شده آسیب دیده باشد. لطفاً مجدداً دانلود کنید.';
      case 'UNAUTHORIZED':
      case 'TOKEN_EXPIRED':
        return 'نشست کاربری شما منقضی شده است. لطفاً مجدداً وارد حساب کاربری خود شوید.';
      case 'SERVER_ERROR':
      case 'INTERNAL_SERVER_ERROR':
        return 'سرور در حال حاضر با مشکلی مواجه شده است. لطفاً چند دقیقه دیگر دوباره تلاش کنید.';
      case 'PURCHASE_REQUIRED':
        return 'برای مطالعه و مرور این دوره، ابتدا باید آن را خریداری نمایید.';
      default:
        return null;
    }
  }

  /// Map backend error codes to descriptive English messages
  static String? _mapErrorCodeToEnglish(String code) {
    final cleanCode = code.trim().toUpperCase();
    switch (cleanCode) {
      case 'CAPTCHA_INVALID':
      case 'INVALID_CAPTCHA':
        return 'Invalid CAPTCHA answer. Please enter the new security code.';
      case 'OTP_EXPIRED':
        return 'Verification code expired. Please request a new code.';
      case 'INVALID_OTP':
      case 'OTP_INVALID':
        return 'Incorrect 5-digit verification code. Please try again.';
      case 'TOO_MANY_REQUESTS':
      case 'RATE_LIMIT_EXCEEDED':
        return 'Too many requests. Please wait a few minutes and try again.';
      case 'USER_NOT_FOUND':
        return 'User account not found. Please verify your details.';
      case 'USER_BLOCKED':
        return 'Your account has been blocked. Please contact support.';
      case 'TERMS_NOT_ACCEPTED':
        return 'Please accept the Terms & Conditions to proceed.';
      case 'CHECKSUM_MISMATCH':
        return 'Course package verification failed. The file may be corrupted.';
      case 'UNAUTHORIZED':
      case 'TOKEN_EXPIRED':
        return 'Your session has expired. Please log in again.';
      case 'SERVER_ERROR':
      case 'INTERNAL_SERVER_ERROR':
        return 'The server encountered an error. Please try again later.';
      case 'PURCHASE_REQUIRED':
        return 'You must purchase this course before studying its flashcards.';
      default:
        return null;
    }
  }

  /// Map Dio exceptions to informative Persian messages
  static String _mapDioExceptionToPersian(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'ارتباط با سرور برقرار نشد یا مهلت زمان اتصال به پایان رسید. لطفاً اتصال اینترنت خود را بررسی کرده و مجدداً تلاش کنید.';
    }

    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      // Extract error_code or message from response payload if present
      if (data is Map) {
        final backendCode = data['error_code'] ?? data['errorCode'];
        if (backendCode != null) {
          final translated = _mapErrorCodeToPersian(backendCode.toString());
          if (translated != null) return translated;
        }

        final backendMsg = data['message'];
        if (backendMsg != null && backendMsg is String) {
          final translatedMsg = _translateStringMessage(backendMsg);
          if (translatedMsg != backendMsg) return translatedMsg;
        }
      }

      switch (statusCode) {
        case 400:
          return 'درخواست ارسالی نامعتبر است. لطفاً اطلاعات ورودی را بررسی نموده و دوباره تلاش کنید.';
        case 401:
          return 'نشست کاربری شما منقضی شده است. لطفاً مجدداً وارد حساب کاربری خود شوید.';
        case 403:
          return 'شما دسترسی لازم برای انجام این عملیات را ندارید.';
        case 404:
          return 'اطلاعات مورد نظر روی سرور یافت نشد.';
        case 429:
          return 'تعداد درخواست‌های شما بیش از حد مجاز است. لطفاً چند دقیقه دیگر دوباره تلاش کنید.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'سرور در حال حاضر پاسخگو نیست یا در حال به‌روزرسانی می‌باشد. لطفاً شکیبا باشید و بعداً تلاش کنید.';
      }
    }

    return 'خطا در ارتباط با شبکه یا سرور. لطفاً اتصال اینترنت خود را بررسی کنید.';
  }

  /// Map Dio exceptions to informative English messages
  static String _mapDioExceptionToEnglish(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Connection timed out or failed. Please check your internet connection.';
    }

    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (data is Map) {
        final backendCode = data['error_code'] ?? data['errorCode'];
        if (backendCode != null) {
          final translated = _mapErrorCodeToEnglish(backendCode.toString());
          if (translated != null) return translated;
        }
        final backendMsg = data['message'];
        if (backendMsg != null && backendMsg is String) {
          return backendMsg;
        }
      }

      switch (statusCode) {
        case 400:
          return 'Invalid request parameters. Please verify input and try again.';
        case 401:
          return 'Your session has expired. Please log in again.';
        case 403:
          return 'Access denied.';
        case 404:
          return 'Requested resource not found on server.';
        case 429:
          return 'Too many requests. Please wait a few minutes and try again.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server is currently unavailable or undergoing maintenance. Please try again later.';
      }
    }

    return 'Network communication error. Please check your connection.';
  }

  /// Match known English error strings or technical stack traces to clear Persian messages
  static String _translateStringMessage(String msg) {
    final lower = msg.toLowerCase();

    if (lower.contains('captcha') || lower.contains('کپچا')) {
      return 'کد امنیتی (کپچا) اشتباه است یا به درستی وارد نشده است.';
    }
    if (lower.contains('otp') || lower.contains('verification code') || lower.contains('کد تایید')) {
      return 'کد تایید ۵ رقمی وارد شده اشتباه یا منقضی شده است. لطفاً کد جدید درخواست کنید.';
    }
    if (lower.contains('mobile') || lower.contains('phone number') || lower.contains('شماره موبایل')) {
      return 'شماره موبایل وارد شده معتبر نیست. لطفاً یک شماره ۱۱ رقمی معتبر (مانند 09123456789) وارد کنید.';
    }
    if (lower.contains('checksum') || lower.contains('verification failed')) {
      return 'تایید اصالت فایل دوره با خطا مواجه شد. ممکن است فایل دانلود شده آسیب دیده باشد.';
    }
    if (lower.contains('no internet connection') || lower.contains('offline') || lower.contains('socketexception') || lower.contains('connection refused')) {
      return 'ارتباط با اینترنت برقرار نیست. لطفاً اتصال شبکه خود را بررسی کنید.';
    }
    if (lower.contains('failed to load courses') || lower.contains('failed to load catalog')) {
      return 'خطا در دریافت لیست دوره‌ها از سرور. لطفاً اتصال اینترنت را بررسی کنید.';
    }
    if (lower.contains('failed to download course') || lower.contains('download error')) {
      return 'خطا در دانلود فایل دوره. لطفاً فضای ذخیره‌سازی دستگاه و اینترنت را بررسی کنید.';
    }
    if (lower.contains('failed to process and save course') || lower.contains('zip') || lower.contains('unarchive')) {
      return 'خطا در استخراج و ذخیره‌سازی فایل دوره. لطفاً از وجود حافظه کافی روی دستگاه اطمینان حاصل کنید.';
    }
    if (lower.contains('offline course downloads are available')) {
      return 'امکان دانلود آفلاین دوره در نسخه وب وجود ندارد و مخصوص اپلیکیشن موبایل است.';
    }
    if (lower.contains('pick image') || lower.contains('image_picker')) {
      return 'خطا در انتخاب تصویر از گالری. لطفاً دسترسی برنامه به تصاویر را بررسی نمایید.';
    }
    if (lower.contains('record') || lower.contains('microphone')) {
      return 'خطا در ضبط صدا. لطفاً دسترسی برنامه به میکروفون دستگاه را بپذیرید.';
    }
    if (lower.contains('audio') || lower.contains('play audio')) {
      return 'خطا در پخش فایل صوتی کارت.';
    }
    if (lower.contains('save card') || lower.contains('create card')) {
      return 'خطا در ذخیره‌سازی کارت اختصاصی روی حافظه دستگاه.';
    }
    if (lower.contains('create course')) {
      return 'خطا در ایجاد دوره جدید.';
    }
    if (lower.contains('delete course')) {
      return 'خطا در حذف دوره.';
    }
    if (lower.contains('purchase_required') || lower.contains('purchase required')) {
      return 'برای مطالعه و مرور این دوره، ابتدا باید آن را خریداری نمایید.';
    }
    if (lower.contains('load study queue')) {
      return 'خطا در بارگذاری صف کارت‌های آماده مرور. لطفاً صفحه را بازخوانی کنید.';
    }
    if (lower.contains('submit review')) {
      return 'خطا در ثبت وضعیت پاسخ کارت.';
    }
    if (lower.contains('update favorites')) {
      return 'خطا در به‌روزرسانی لیست نشان‌شده‌ها.';
    }
    if (lower.contains('jump') || lower.contains('reset progress')) {
      return 'خطا در تغییر وضعیت یا بازنشانی پیشرفت کارت.';
    }
    if (lower.contains('invalid backup file format')) {
      return 'فرمت فایل انتخاب‌شده معتبر نیست. لطفاً فایل پشتیبان معتبر انتخاب کنید.';
    }
    if (lower.contains('incorrect password')) {
      return 'رمز عبور وارد شده برای فایل پشتیبان اشتباه است یا فایل آسیب دیده است.';
    }
    if (lower.contains('unsupported backup version')) {
      return 'نسخه فایل پشتیبان با این نسخه از برنامه سازگار نیست.';
    }
    if (lower.contains('backup failed')) {
      return 'پشتیبان‌گیری ناموفق بود. لطفاً فضای حافظه و رمز عبور را بررسی کنید.';
    }
    if (lower.contains('restore failed')) {
      return 'بازیابی فایل پشتیبان ناموفق بود. لطفاً رمز عبور را بررسی کنید.';
    }

    if (lower.contains('status code of 429') || lower.contains('too many requests') || lower.contains('rate_limit') || lower.contains('code 429')) {
      return 'تعداد درخواست‌های شما بیش از حد مجاز است. لطفاً چند دقیقه صبر کرده و سپس دوباره تلاش کنید.';
    }
    if (lower.contains('status code of 400') || lower.contains('bad request') || lower.contains('code 400')) {
      return 'درخواست ارسالی نامعتبر است. لطفاً ورودی‌های خود را بررسی کنید.';
    }
    if (lower.contains('status code of 401') || lower.contains('unauthorized') || lower.contains('code 401')) {
      return 'نشست کاربری شما منقضی شده است. لطفاً مجدداً وارد حساب کاربری شوید.';
    }
    if (lower.contains('status code of 403') || lower.contains('forbidden') || lower.contains('code 403')) {
      return 'شما دسترسی لازم برای انجام این عملیات را ندارید.';
    }
    if (lower.contains('status code of 404') || lower.contains('not found') || lower.contains('code 404')) {
      return 'اطلاعات مورد نظر روی سرور یافت نشد.';
    }
    if (lower.contains('status code of 500') || lower.contains('status code of 502') || lower.contains('status code of 503') || lower.contains('status code of 504') || lower.contains('internal server error')) {
      return 'سرور موقتاً پاسخگو نیست یا در حال به‌روزرسانی است. لطفاً کمی بعد دوباره تلاش کنید.';
    }
    if (lower.contains('validatestatus') || lower.contains('this exception was thrown because')) {
      return 'ارتباط با سرور با خطا مواجه شد. لطفاً دوباره تلاش کنید.';
    }

    // If message is already in Persian (contains Persian characters)
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) {
      return msg;
    }

    // Default fallback
    return 'خطایی رخ داده است. لطفاً مجدداً تلاش کنید.';
  }
}
