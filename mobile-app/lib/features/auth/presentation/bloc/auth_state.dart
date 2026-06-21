import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

/// State emitted when the CAPTCHA is successfully loaded from backend.
class CaptchaLoadedState extends AuthState {
  final String captchaId;
  final String imageBase64;

  const CaptchaLoadedState({
    required this.captchaId,
    required this.imageBase64,
  });

  @override
  List<Object?> get props => [captchaId, imageBase64];
}

/// State emitted when the verification code is sent.
class OtpSentState extends AuthState {
  final String mobileNumber;

  const OtpSentState({required this.mobileNumber});

  @override
  List<Object?> get props => [mobileNumber];
}

/// State emitted when OTP is verified but user must accept the Terms & Rules contract.
class TermsPendingState extends AuthState {
  final String mobileNumber;
  final String token;
  final String refreshToken;

  const TermsPendingState({
    required this.mobileNumber,
    required this.token,
    required this.refreshToken,
  });

  @override
  List<Object?> get props => [mobileNumber, token, refreshToken];
}

/// State emitted when OTP & Terms are completed but user profile (fields) is still a placeholder.
class ProfilePendingState extends AuthState {
  final String mobileNumber;
  final String token;
  final String refreshToken;

  const ProfilePendingState({
    required this.mobileNumber,
    required this.token,
    required this.refreshToken,
  });

  @override
  List<Object?> get props => [mobileNumber, token, refreshToken];
}

/// State emitted when the user is successfully authenticated and profile is active.
class AuthenticatedState extends AuthState {
  final User user;
  final String token;

  const AuthenticatedState({
    required this.user,
    required this.token,
  });

  @override
  List<Object?> get props => [user, token];
}

/// State emitted when there is no active session on start or after logout.
class UnauthenticatedState extends AuthState {}

/// State emitted when any auth API or persistence operation fails.
class AuthErrorState extends AuthState {
  final String message;
  final String? errorCode;

  const AuthErrorState({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}
