import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class GetCaptcha implements UseCase<Either<Failure, (String captchaId, String imageBase64)>, NoParams> {
  final AuthRepository repository;

  GetCaptcha(this.repository);

  @override
  Future<Either<Failure, (String captchaId, String imageBase64)>> call(NoParams params) {
    return repository.getCaptcha();
  }
}
