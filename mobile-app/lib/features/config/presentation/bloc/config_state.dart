import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';

abstract class ConfigState extends Equatable {
  final RemoteConfig? config;

  const ConfigState({this.config});

  @override
  List<Object?> get props => [config];
}

class ConfigInitial extends ConfigState {
  const ConfigInitial({RemoteConfig? config}) : super(config: config);
}

class ConfigLoading extends ConfigState {
  const ConfigLoading({RemoteConfig? previousConfig}) : super(config: previousConfig);
}

class ConfigLoaded extends ConfigState {
  @override
  RemoteConfig get config => super.config!;

  const ConfigLoaded({required RemoteConfig config}) : super(config: config);

  @override
  List<Object?> get props => [config];
}

class ConfigMaintenance extends ConfigState {
  @override
  RemoteConfig get config => super.config!;

  const ConfigMaintenance({required RemoteConfig config}) : super(config: config);

  @override
  List<Object?> get props => [config];
}

class ConfigError extends ConfigState {
  final String message;

  const ConfigError({required this.message, RemoteConfig? previousConfig})
      : super(config: previousConfig);

  @override
  List<Object?> get props => [message, config];
}
