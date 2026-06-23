import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';

class SecurityBlockScreen extends StatelessWidget {
  const SecurityBlockScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.security_update_warning_rounded,
                color: AppColors.error,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Security Block',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'For security and content protection reasons, the Leitner Learning Platform cannot be run on rooted or jailbroken devices.\n\nPlease use a secure, non-rooted device to access your courses and learning progress.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
