import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/auth/presentation/screens/home_hub_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/otp_request_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/terms_acceptance_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/profile_completion_screen.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency locator
  await di.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
      child: MaterialApp(
        title: 'Leitner Learning Platform',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        // Only rebuild the main gateway for primary structural states.
        return current is AuthenticatedState ||
            current is UnauthenticatedState ||
            current is TermsPendingState ||
            current is ProfilePendingState ||
            current is AuthInitialState ||
            (current is AuthLoadingState && previous is AuthInitialState);
      },
      builder: (context, state) {
        if (state is AuthenticatedState) {
          return const HomeHubScreen();
        } else if (state is TermsPendingState) {
          return TermsAcceptanceScreen(
            mobileNumber: state.mobileNumber,
            token: state.token,
            refreshToken: state.refreshToken,
          );
        } else if (state is ProfilePendingState) {
          return ProfileCompletionScreen(
            mobileNumber: state.mobileNumber,
            token: state.token,
            refreshToken: state.refreshToken,
          );
        } else if (state is UnauthenticatedState) {
          return const OtpRequestScreen();
        }
        
        // Boot loading screen
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Loading Platform...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
