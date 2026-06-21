import 'package:equatable/equatable.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class RequestOtp implements UseCase<Either<Failure, bool>, RequestOtpParams> {
  final AuthRepository repository;

  RequestOtp(this.repository);

  @override
  Future<Either<Failure, bool>> call(RequestOtpParams params) {
    return repository.requestOtp(
      mobileNumber: params.mobileNumber,
      captchaId: params.captchaId,
      captchaAnswer: params.captchaAnswer,
    );
  }
}

class RequestOtpParams extends Equatable {
  final String mobileNumber;
  final String captchaId;
  final String captchaAnswer;

  const RequestOtpParams({
    required this.mobileNumber,
    required this.captchaId,
    required this.captchaAnswer,
  });

  @override
  List<Object?> get props => [mobileNumber, captchaId, captchaAnswer];
}
