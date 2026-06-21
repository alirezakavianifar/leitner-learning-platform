import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class GetProfile implements UseCase<Either<Failure, User>, NoParams> {
  final AuthRepository repository;

  GetProfile(this.repository);

  @override
  Future<Either<Failure, User>> call(NoParams params) {
    return repository.getProfile();
  }
}
