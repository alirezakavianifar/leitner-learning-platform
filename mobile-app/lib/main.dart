import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/auth/presentation/screens/home_hub_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/otp_request_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/terms_acceptance_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/profile_completion_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/security_block_screen.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_event.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import 'package:mobile_app/features/config/presentation/screens/maintenance_screen.dart';
import 'injection_container.dart' as di;

void main({String flavor = 'store'}) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency locator
  await di.init(flavor: flavor);

  bool isJailbroken = false;
  try {
    isJailbroken = await FlutterJailbreakDetection.jailbroken;
  } catch (_) {
    isJailbroken = false;
  }
  
  runApp(MyApp(isJailbroken: isJailbroken));
}

class MyApp extends StatelessWidget {
  final bool isJailbroken;

  const MyApp({Key? key, this.isJailbroken = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConfigBloc>(
          create: (_) => di.sl<ConfigBloc>()..add(LoadConfigEvent()),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
        ),
      ],
      child: MaterialApp(
        title: 'Leitner Learning Platform',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: isJailbroken ? const SecurityBlockScreen() : const AppGate(),
      ),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigBloc, ConfigState>(
      builder: (context, state) {
        if (state is ConfigMaintenance) {
          return const MaintenanceScreen();
        }

        if (state is ConfigLoading || state is ConfigInitial) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Checking Configuration...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return const AuthGate();
      },
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
