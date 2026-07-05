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
      emit(ThemeState(mode, isLight ? AppTheme.lightTheme : AppTheme.darkTheme));
    });

    on<ChangeThemeEvent>((event, emit) async {
      final isLight = event.themeMode == ThemeMode.light;
      await _sharedPreferences.setBool('theme_is_light', isLight);
      AppColors.setTheme(!isLight);
      emit(ThemeState(event.themeMode, isLight ? AppTheme.lightTheme : AppTheme.darkTheme));
    });
  }
}
