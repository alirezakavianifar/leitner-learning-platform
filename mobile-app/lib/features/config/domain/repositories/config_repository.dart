import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';

abstract class ConfigRepository {
  Future<Either<Failure, RemoteConfig>> getRemoteConfig();
}
