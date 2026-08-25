import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/localization/locale_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/app/theme_bloc.dart';
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
import 'package:mobile_app/core/diagnostics/app_logger.dart';

/// Global navigator key — used by the Dio 401 interceptor to redirect to
/// the login screen without requiring a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main({String flavor = 'store'}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize structured logging and rotating local file sink
  await AppLogger().init();

  // Catch uncaught errors bubbled up from the Flutter framework
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger().error(
      'Uncaught Flutter framework error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  // Catch uncaught asynchronous and platform-level exceptions
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger().error('Uncaught asynchronous platform error', error, stack);
    return true;
  };

  AppLogger().info('Starting application. Flavor: $flavor');
  
  if (!kIsWeb && Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize dependency locator
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  await di.init(
    apiBaseUrl: apiBaseUrl.isNotEmpty ? apiBaseUrl : null,
    flavor: flavor,
  );

  bool isJailbroken = false;
  // Jailbreak/Root detection is disabled temporarily for cloud emulator testing.
  
  runApp(MyApp(isJailbroken: isJailbroken));
}

class MyApp extends StatelessWidget {
  final bool isJailbroken;

  const MyApp({Key? key, this.isJailbroken = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleBloc>(
          create: (_) => di.sl<LocaleBloc>()..add(LoadSavedLocaleEvent()),
        ),
        BlocProvider<ThemeBloc>(
          create: (_) => di.sl<ThemeBloc>()..add(LoadThemeEvent()),
        ),
        BlocProvider<ConfigBloc>(
          create: (_) => di.sl<ConfigBloc>()..add(LoadConfigEvent()),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
        ),
      ],
      child: BlocBuilder<LocaleBloc, LocaleState>(
        builder: (context, localeState) {
          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp(
                title: 'RightLearn',
                theme: themeState.themeData,
                debugShowCheckedModeBanner: false,
                locale: localeState.locale,
                supportedLocales: const [
                  Locale('fa'),
                  Locale('en'),
                ],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: isJailbroken ? const SecurityBlockScreen() : const AppGate(),
                navigatorKey: navigatorKey,
              );
            },
          );
        },
      ),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigBloc, ConfigState>(
      buildWhen: (previous, current) {
        // If we are already displaying the app with a loaded configuration,
        // do not rebuild AppGate back to the full-screen loading spinner on background refreshes.
        if (current is ConfigLoading && current.config != null) {
          return false;
        }
        return true;
      },
      builder: (context, state) {
        if (state is ConfigMaintenance) {
          return const MaintenanceScreen();
        }

        if ((state is ConfigLoading && state.config == null) ||
            (state is ConfigInitial && state.config == null)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).translate('checking_config'),
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
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).translate('loading_platform'),
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
