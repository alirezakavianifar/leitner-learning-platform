import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Events
abstract class LocaleEvent {}

class ChangeLocaleEvent extends LocaleEvent {
  final Locale locale;
  ChangeLocaleEvent(this.locale);
}

class LoadSavedLocaleEvent extends LocaleEvent {}

// States
class LocaleState {
  final Locale locale;
  LocaleState(this.locale);
}

// BLoC
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  final SharedPreferences sharedPreferences;
  static const String _kLocaleKey = 'selected_locale_code';

  LocaleBloc({required this.sharedPreferences}) : super(LocaleState(const Locale('fa'))) {
    on<LoadSavedLocaleEvent>((event, emit) {
      final code = sharedPreferences.getString(_kLocaleKey) ?? 'fa';
      emit(LocaleState(Locale(code)));
    });

    on<ChangeLocaleEvent>((event, emit) async {
      await sharedPreferences.setString(_kLocaleKey, event.locale.languageCode);
      emit(LocaleState(event.locale));
    });
  }
}
