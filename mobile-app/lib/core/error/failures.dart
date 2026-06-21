import 'package:equatable/equatable.dart';

/// Base class representing operational failures in the application.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Represents errors returned from the backend servers or APIs.
class ServerFailure extends Failure {
  final String? errorCode;
  const ServerFailure(String message, {this.errorCode}) : super(message);

  @override
  List<Object?> get props => [message, errorCode];
}

/// Represents failures in local storage or file reads/writes.
class CacheFailure extends Failure {
  const CacheFailure(String message) : super(message);
}

/// Represents connection/offline related failures.
class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message);
}
