import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/services/sms_retriever_service.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/auth/presentation/screens/otp_verification_screen.dart';

class FakeSmsRetriever implements SmsRetriever {
  final String? codeToReturn;
  bool isDisposed = false;

  FakeSmsRetriever({this.codeToReturn});

  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    return codeToReturn;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}

class SetMockStateEvent extends AuthEvent {
  final AuthState state;
  const SetMockStateEvent(this.state);
}

class MockAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  final List<AuthEvent> capturedEvents = [];

  MockAuthBloc([AuthState? initialState]) : super(initialState ?? AuthInitialState()) {
    on<SetMockStateEvent>((event, emit) {
      emit(event.state);
    });
    on<AuthEvent>((event, emit) {
      if (event is! SetMockStateEvent) {
        capturedEvents.add(event);
      }
    });
  }

  void setMockState(AuthState state) {
    add(SetMockStateEvent(state));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SmsRetrieverService Unit Tests', () {
    test('getSmsCode should return null safely on non-Android test environment', () async {
      final service = SmsRetrieverService();
      final result = await service.getSmsCode();
      expect(result, isNull);
    });

    test('dispose should complete without exception on non-Android test environment', () async {
      final service = SmsRetrieverService();
      expect(() async => await service.dispose(), returnsNormally);
    });
  });

  group('OtpVerificationScreen Widget Tests', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
    });

    tearDown(() async {
      await mockAuthBloc.close();
    });

    Widget createTestWidget({
      required String mobileNumber,
      SmsRetriever? smsRetriever,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('fa'),
        ],
        locale: const Locale('en'),
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: OtpVerificationScreen(
            mobileNumber: mobileNumber,
            smsRetriever: smsRetriever ?? FakeSmsRetriever(codeToReturn: null),
          ),
        ),
      );
    }

    testWidgets('Renders Pinput widget, countdown timer, and mobile number', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(mobileNumber: '09123456789'));
      await tester.pump();

      expect(find.textContaining('09123456789'), findsOneWidget);
      expect(find.byType(Pinput), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Automatically autofills and submits when SmsRetriever yields a code', (WidgetTester tester) async {
      final autoRetriever = FakeSmsRetriever(codeToReturn: '88776');
      await tester.pumpWidget(createTestWidget(
        mobileNumber: '09123456789',
        smsRetriever: autoRetriever,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockAuthBloc.capturedEvents.isNotEmpty, isTrue);
      final event = mockAuthBloc.capturedEvents.first as VerifyOtpEvent;
      expect(event.mobileNumber, '09123456789');
      expect(event.otpCode, '88776');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Manually typing 5 digits triggers VerifyOtpEvent', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        mobileNumber: '09123456789',
        smsRetriever: FakeSmsRetriever(codeToReturn: null),
      ));
      await tester.pump();

      final pinputFinder = find.byType(Pinput);
      expect(pinputFinder, findsOneWidget);

      await tester.enterText(pinputFinder, '12345');
      await tester.pump();

      expect(mockAuthBloc.capturedEvents.isNotEmpty, isTrue);
      final event = mockAuthBloc.capturedEvents.first as VerifyOtpEvent;
      expect(event.mobileNumber, '09123456789');
      expect(event.otpCode, '12345');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Displays loading indicator when state is AuthLoadingState', (WidgetTester tester) async {
      mockAuthBloc.setMockState(AuthLoadingState());
      await tester.pumpWidget(createTestWidget(
        mobileNumber: '09123456789',
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Disposes smsRetriever when unmounted', (WidgetTester tester) async {
      final retriever = FakeSmsRetriever(codeToReturn: null);
      await tester.pumpWidget(createTestWidget(
        mobileNumber: '09123456789',
        smsRetriever: retriever,
      ));
      await tester.pump();

      expect(retriever.isDisposed, isFalse);

      // Unmount cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(retriever.isDisposed, isTrue);
    });
  });
}
