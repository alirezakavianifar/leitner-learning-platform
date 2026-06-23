import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';

abstract class ConfigState extends Equatable {
  const ConfigState();

  @override
  List<Object?> get props => [];
}

class ConfigInitial extends ConfigState {}

class ConfigLoading extends ConfigState {}

class ConfigLoaded extends ConfigState {
  final RemoteConfig config;

  const ConfigLoaded({required this.config});

  @override
  List<Object?> get props => [config];
}

class ConfigMaintenance extends ConfigState {
  final RemoteConfig config;

  const ConfigMaintenance({required this.config});

  @override
  List<Object?> get props => [config];
}

class ConfigError extends ConfigState {
  final String message;

  const ConfigError({required this.message});

  @override
  List<Object?> get props => [message];
}
