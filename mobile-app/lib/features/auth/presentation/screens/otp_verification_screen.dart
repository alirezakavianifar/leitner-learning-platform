import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/services/sms_retriever_service.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'terms_acceptance_screen.dart';
import 'profile_completion_screen.dart';
import 'home_hub_screen.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/error/error_formatter.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String mobileNumber;
  final SmsRetriever? smsRetriever;

  const OtpVerificationScreen({
    super.key,
    required this.mobileNumber,
    this.smsRetriever,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  late final SmsRetriever _smsRetriever;
  
  Timer? _timer;
  int _secondsRemaining = 120;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _smsRetriever = widget.smsRetriever ?? SmsRetrieverService();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smsRetriever.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 120;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        _timer?.cancel();
      }
    });
  }

  void _submit([String? pin]) {
    final code = (pin ?? _otpController.text).trim();
    if (code.length == 5) {
      context.read<AuthBloc>().add(
            VerifyOtpEvent(
              mobileNumber: widget.mobileNumber,
              otpCode: code,
            ),
          );
    } else if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            VerifyOtpEvent(
              mobileNumber: widget.mobileNumber,
              otpCode: _otpController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context);

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: TextStyle(
        fontSize: 22,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is TermsPendingState) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TermsAcceptanceScreen(
                  mobileNumber: state.mobileNumber,
                  token: state.token,
                  refreshToken: state.refreshToken,
                ),
              ),
              (route) => false,
            );
          } else if (state is ProfilePendingState) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileCompletionScreen(
                  mobileNumber: state.mobileNumber,
                  token: state.token,
                  refreshToken: state.refreshToken,
                ),
              ),
              (route) => false,
            );
          } else if (state is AuthenticatedState) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeHubScreen()),
              (route) => false,
            );
          } else if (state is AuthErrorState) {
            final errorMessage = AppErrorFormatter.formatError(
              state.message,
              context: context,
              errorCode: state.errorCode,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoadingState;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      loc.verifyPhone,
                      style: textTheme.displayMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${loc.enterCodeSentTo}\n${widget.mobileNumber}',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Modern 5-box PIN field with SMS Retriever & iOS Autofill
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Center(
                        child: Pinput(
                          controller: _otpController,
                          length: 5,
                          autofocus: true,
                          smsRetriever: _smsRetriever,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: submittedPinTheme,
                          errorPinTheme: errorPinTheme,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.trim().length != 5) {
                              return loc.enterCodeValidationError;
                            }
                            return null;
                          },
                          pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                          showCursor: true,
                          onCompleted: (pin) {
                            _submit(pin);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Countdown timer & Resend code
                    Center(
                      child: _canResend
                          ? TextButton(
                              onPressed: () {
                                // Pop back to OTP request screen so they can request with a new CAPTCHA
                                Navigator.pop(context);
                              },
                              child: Text(
                                loc.resendCode,
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : Text(
                              '${loc.resendCodeIn} $_secondsRemaining ${loc.seconds}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                    const SizedBox(height: 48),

                    // Verify button
                    ElevatedButton(
                      onPressed: isLoading ? null : () => _submit(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              loc.verifyAndContinue,
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
