import 'package:equatable/equatable.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';

class UpdateProfile implements UseCase<Either<Failure, User>, UpdateProfileParams> {
  final AuthRepository repository;

  UpdateProfile(this.repository);

  @override
  Future<Either<Failure, User>> call(UpdateProfileParams params) {
    return repository.updateProfile(
      username: params.username,
      interests: params.interests,
      educationalField: params.educationalField,
      educationalLevel: params.educationalLevel,
    );
  }
}

class UpdateProfileParams extends Equatable {
  final String username;
  final String? interests;
  final String? educationalField;
  final String? educationalLevel;

  const UpdateProfileParams({
    required this.username,
    this.interests,
    this.educationalField,
    this.educationalLevel,
  });

  @override
  List<Object?> get props => [username, interests, educationalField, educationalLevel];
}
