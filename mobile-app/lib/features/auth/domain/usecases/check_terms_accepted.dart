import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class CheckTermsAccepted implements UseCase<Either<Failure, bool>, NoParams> {
  final AuthRepository repository;

  CheckTermsAccepted(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) {
    return repository.checkTermsAccepted();
  }
}
