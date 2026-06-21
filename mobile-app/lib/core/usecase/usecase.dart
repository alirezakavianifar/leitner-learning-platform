import 'package:equatable/equatable.dart';

/// Base UseCase class matching feature Clean Architecture contracts.
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Helper class to represent a parameter-less usecase execution.
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}

/// A lightweight, generic Either type used to handle operation outcomes.
/// Typically stores a [Failure] on the Left and a success [R] result on the Right.
abstract class Either<L, R> {
  const Either();

  T fold<T>(T Function(L left) fnL, T Function(R right) fnR);

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR) => fnL(value);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR) => fnR(value);
}
