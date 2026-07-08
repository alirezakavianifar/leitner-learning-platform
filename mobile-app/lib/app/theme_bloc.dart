import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';

abstract class ThemeEvent {}

class LoadThemeEvent extends ThemeEvent {}

class ChangeThemeEvent extends ThemeEvent {
  final ThemeMode themeMode;
  ChangeThemeEvent(this.themeMode);
}

class ChangePrimaryColorEvent extends ThemeEvent {
  final int primaryColorHex;
  final int secondaryColorHex;
  ChangePrimaryColorEvent({
    required this.primaryColorHex,
    required this.secondaryColorHex,
  });
}

class ThemeState {
  final ThemeMode themeMode;
  final ThemeData themeData;

  ThemeState(this.themeMode, this.themeData);
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences _sharedPreferences;

  ThemeBloc(this._sharedPreferences) : super(ThemeState(ThemeMode.light, AppTheme.lightTheme)) {
    on<LoadThemeEvent>((event, emit) {
      final isLight = _sharedPreferences.getBool('theme_is_light') ?? true;
      final mode = isLight ? ThemeMode.light : ThemeMode.dark;
      AppColors.setTheme(!isLight);
      
      final primaryHex = _sharedPreferences.getInt('theme_primary_color') ?? 0xFF6B4EE6;
      final secondaryHex = _sharedPreferences.getInt('theme_secondary_color') ?? 0xFF09E5C3;
      AppColors.primary = Color(primaryHex);
      AppColors.secondary = Color(secondaryHex);

      emit(ThemeState(mode, isLight ? AppTheme.lightTheme : AppTheme.darkTheme));
    });

    on<ChangeThemeEvent>((event, emit) async {
      final isLight = event.themeMode == ThemeMode.light;
      await _sharedPreferences.setBool('theme_is_light', isLight);
      AppColors.setTheme(!isLight);
      
      final primaryHex = _sharedPreferences.getInt('theme_primary_color') ?? 0xFF6B4EE6;
      final secondaryHex = _sharedPreferences.getInt('theme_secondary_color') ?? 0xFF09E5C3;
      AppColors.primary = Color(primaryHex);
      AppColors.secondary = Color(secondaryHex);

      emit(ThemeState(event.themeMode, isLight ? AppTheme.lightTheme : AppTheme.darkTheme));
    });

    on<ChangePrimaryColorEvent>((event, emit) async {
      await _sharedPreferences.setInt('theme_primary_color', event.primaryColorHex);
      await _sharedPreferences.setInt('theme_secondary_color', event.secondaryColorHex);
      
      final isLight = state.themeMode == ThemeMode.light;
      AppColors.setTheme(!isLight);
      AppColors.primary = Color(event.primaryColorHex);
      AppColors.secondary = Color(event.secondaryColorHex);

      emit(ThemeState(state.themeMode, isLight ? AppTheme.lightTheme : AppTheme.darkTheme));
    });
  }
}
