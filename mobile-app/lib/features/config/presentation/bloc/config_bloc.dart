import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/features/config/domain/repositories/config_repository.dart';
import 'config_event.dart';
import 'config_state.dart';

class ConfigBloc extends Bloc<ConfigEvent, ConfigState> {
  final ConfigRepository configRepository;

  ConfigBloc({required this.configRepository})
      : super(
          configRepository.getCachedConfig() != null
              ? (configRepository.getCachedConfig()!.maintenanceMode
                  ? ConfigMaintenance(config: configRepository.getCachedConfig()!)
                  : ConfigLoaded(config: configRepository.getCachedConfig()!))
              : const ConfigInitial(),
        ) {
    on<LoadConfigEvent>(_onLoadConfig);
  }

  Future<void> _onLoadConfig(
    LoadConfigEvent event,
    Emitter<ConfigState> emit,
  ) async {
    final previousConfig = state.config;
    emit(ConfigLoading(previousConfig: previousConfig));
    final result = await configRepository.getRemoteConfig();
    result.fold(
      (failure) => emit(ConfigError(message: failure.message, previousConfig: previousConfig)),
      (config) {
        if (config.maintenanceMode) {
          emit(ConfigMaintenance(config: config));
        } else {
          emit(ConfigLoaded(config: config));
        }
      },
    );
  }
}
