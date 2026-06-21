import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers loading of a new visual mathematical CAPTCHA.
class LoadCaptchaEvent extends AuthEvent {}

/// Triggers request for OTP after validating mobile format & CAPTCHA.
class RequestOtpEvent extends AuthEvent {
  final String mobileNumber;
  final String captchaId;
  final String captchaAnswer;

  const RequestOtpEvent({
    required this.mobileNumber,
    required this.captchaId,
    required this.captchaAnswer,
  });

  @override
  List<Object?> get props => [mobileNumber, captchaId, captchaAnswer];
}

/// Triggers OTP code verification.
class VerifyOtpEvent extends AuthEvent {
  final String mobileNumber;
  final String otpCode;

  const VerifyOtpEvent({
    required this.mobileNumber,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [mobileNumber, otpCode];
}

/// Triggers user acceptance of the Terms & Rules contract.
class AcceptTermsEvent extends AuthEvent {
  final String mobileNumber;
  final String token;
  final String refreshToken;

  const AcceptTermsEvent({
    required this.mobileNumber,
    required this.token,
    required this.refreshToken,
  });

  @override
  List<Object?> get props => [mobileNumber, token, refreshToken];
}

/// Triggers profile completion/updates.
class UpdateProfileEvent extends AuthEvent {
  final String username;
  final String? interests;
  final String? educationalField;
  final String? educationalLevel;

  const UpdateProfileEvent({
    required this.username,
    this.interests,
    this.educationalField,
    this.educationalLevel,
  });

  @override
  List<Object?> get props => [username, interests, educationalField, educationalLevel];
}

/// Triggered at app startup to check existing credentials & Terms state.
class CheckAuthStatusEvent extends AuthEvent {}

/// Triggers session deletion.
class LogoutEvent extends AuthEvent {}
