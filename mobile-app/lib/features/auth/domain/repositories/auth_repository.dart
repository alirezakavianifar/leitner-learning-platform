import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';

/// Abstract repository boundary separating domain logic from implementation details.
abstract class AuthRepository {
  /// Fetches a new mathematical SVG CAPTCHA.
  Future<Either<Failure, (String captchaId, String imageBase64)>> getCaptcha();

  /// Requests a 5-digit verification code.
  Future<Either<Failure, bool>> requestOtp({
    required String mobileNumber,
    required String captchaId,
    required String captchaAnswer,
  });

  /// Verifies OTP code and gets auth tokens + status.
  Future<Either<Failure, (String token, String refreshToken, String userStatus)>> verifyOtp({
    required String mobileNumber,
    required String otpCode,
  });

  /// Fetches profile details of the authenticated user.
  Future<Either<Failure, User>> getProfile();

  /// Updates profile metadata (except for mobile number which is read-only).
  Future<Either<Failure, User>> updateProfile({
    required String username,
    String? interests,
    String? educationalField,
    String? educationalLevel,
  });

  /// Checks if terms & rules have been accepted locally.
  Future<Either<Failure, bool>> checkTermsAccepted();

  /// Persists terms & rules acceptance state locally.
  Future<Either<Failure, bool>> acceptTerms();

  /// Deletes tokens and resets login state.
  Future<Either<Failure, bool>> logout();
}
