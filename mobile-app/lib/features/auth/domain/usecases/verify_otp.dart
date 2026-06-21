import 'package:equatable/equatable.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class VerifyOtp implements UseCase<Either<Failure, (String token, String refreshToken, String userStatus)>, VerifyOtpParams> {
  final AuthRepository repository;

  VerifyOtp(this.repository);

  @override
  Future<Either<Failure, (String token, String refreshToken, String userStatus)>> call(VerifyOtpParams params) {
    return repository.verifyOtp(
      mobileNumber: params.mobileNumber,
      otpCode: params.otpCode,
    );
  }
}

class VerifyOtpParams extends Equatable {
  final String mobileNumber;
  final String otpCode;

  const VerifyOtpParams({
    required this.mobileNumber,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [mobileNumber, otpCode];
}
