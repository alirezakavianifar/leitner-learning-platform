import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class AcceptTerms implements UseCase<Either<Failure, bool>, NoParams> {
  final AuthRepository repository;

  AcceptTerms(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) {
    return repository.acceptTerms();
  }
}
