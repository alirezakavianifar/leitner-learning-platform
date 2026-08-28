import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/auth/presentation/screens/otp_verification_screen.dart';

class MockAuthBloc extends Fake implements AuthBloc {
  final List<AuthEvent> dispatchedEvents = [];
  final _stateController = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthInitialState();

  @override
  Stream<AuthState> get stream => _stateController.stream;

  @override
  void add(AuthEvent event) {
    dispatchedEvents.add(event);
  }

  @override
  Future<void> close() async {
    await _stateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OtpVerificationScreen Autofill & AutoSubmit Tests', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
    });

    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fa'),
          Locale('en'),
        ],
        locale: const Locale('fa'),
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: const OtpVerificationScreen(mobileNumber: '09120000000'),
        ),
      );
    }

    testWidgets('OtpVerificationScreen renders AutofillGroup with oneTimeCode hint', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // 1. Verify AutofillGroup is present
      expect(find.byType(AutofillGroup), findsOneWidget);

      // 2. Verify TextField within TextFormField has AutofillHints.oneTimeCode
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testWidgets('Entering Persian digits (۱۲۳۴۵) automatically normalizes to ASCII (12345) and dispatches VerifyOtpEvent', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(mockAuthBloc.dispatchedEvents, isEmpty);

      // Enter 5-digit Persian OTP
      await tester.enterText(find.byType(TextField), '۱۲۳۴۵');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Persian digits were converted to 12345 and auto-dispatched
      expect(mockAuthBloc.dispatchedEvents, isNotEmpty);
      final event = mockAuthBloc.dispatchedEvents.first as VerifyOtpEvent;
      expect(event.mobileNumber, '09120000000');
      expect(event.otpCode, '12345');
    });
  });
}
