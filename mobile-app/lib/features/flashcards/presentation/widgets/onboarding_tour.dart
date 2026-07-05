import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'package:mobile_app/features/auth/presentation/screens/home_hub_screen.dart';

class OnboardingTour {
  static Future<void> showIfNeeded(BuildContext context, {bool force = false}) async {
    final prefs = di.sl<SharedPreferences>();
    final completed = prefs.getBool('first_run_completed') ?? false;

    if (!completed || force) {
      final state = context.findAncestorStateOfType<HomeHubScreenState>();
      if (state != null) {
        state.startInteractiveTour();
      }
    }
  }
}
