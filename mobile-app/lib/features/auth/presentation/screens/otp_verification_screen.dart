import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'terms_acceptance_screen.dart';
import 'profile_completion_screen.dart';
import 'home_hub_screen.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/error/error_formatter.dart';

class DigitsNormalizingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var text = newValue.text;
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(persianDigits[i], '$i');
      text = text.replaceAll(arabicDigits[i], '$i');
    }
    text = text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 5) {
      text = text.substring(0, 5);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  final String mobileNumber;

  const OtpVerificationScreen({Key? key, required this.mobileNumber}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _smartAuth = SmartAuth.instance;
  
  Timer? _timer;
  Timer? _clipboardTimer;
  int _secondsRemaining = 120;
  bool _canResend = false;
  bool _autoSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _otpController.addListener(_onOtpChanged);
    _listenForSmsCode();
    _startClipboardWatcher();
  }

  void _startClipboardWatcher() {
    _checkClipboardForOtp();
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted && _otpController.text.length != 5 && !_autoSubmitting) {
        _checkClipboardForOtp();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForOtp();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _clipboardTimer?.cancel();
    try {
      _smartAuth.removeUserConsentApiListener();
    } catch (_) {}
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    super.dispose();
  }

  String _normalizeDigits(String input) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(persianDigits[i], '$i');
      result = result.replaceAll(arabicDigits[i], '$i');
    }
    return result;
  }

  Future<void> _listenForSmsCode() async {
    try {
      final res = await _smartAuth.getSmsWithUserConsentApi();
      if (res.hasData && res.data != null && mounted) {
        final smsContent = res.data!.sms;
        final extractedCode = res.data!.code;
        final candidate = (extractedCode != null && extractedCode.isNotEmpty)
            ? extractedCode
            : smsContent;
        _handleReceivedCode(candidate);
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  void _handleReceivedCode(String candidate) {
    final normalized = _normalizeDigits(candidate);
    final match = RegExp(r'(?<!\d)\d{5}(?!\d)').firstMatch(normalized) ??
        RegExp(r'\d{5}').firstMatch(normalized);

    if (match != null && mounted) {
      final otp = match.group(0)!;
      if (_otpController.text != otp) {
        _otpController.text = otp;
      }
      _submit();
    }
  }

  Future<void> _checkClipboardForOtp() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.isNotEmpty && mounted) {
        final normalized = _normalizeDigits(text);
        final match = RegExp(r'(?<!\d)\d{5}(?!\d)').firstMatch(normalized);
        if (match != null && _otpController.text != match.group(0)) {
          final otp = match.group(0)!;
          _otpController.text = otp;
          _submit();
        }
      }
    } catch (_) {}
  }

  void _onOtpChanged() {
    final rawText = _otpController.text;
    final normalized = _normalizeDigits(rawText);
    if (normalized != rawText) {
      _otpController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      return;
    }

    final code = normalized.trim();
    if (code.length == 5 && !_autoSubmitting) {
      _autoSubmitting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _submit();
        }
      });
    } else if (code.length < 5) {
      _autoSubmitting = false;
    }
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

  void _submit() {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      TextInput.finishAutofillContext();
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
            _autoSubmitting = false;
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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

                      // OTP field with AutofillHints.oneTimeCode & DigitsNormalizingFormatter
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 5,
                        enableSuggestions: true,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        autofocus: true,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          DigitsNormalizingFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText: '•••••',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length != 5) {
                            return loc.enterCodeValidationError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Paste from SMS / Clipboard helper chip
                      Center(
                        child: TextButton.icon(
                          onPressed: _checkClipboardForOtp,
                          icon: Icon(Icons.paste_rounded, size: 16, color: AppColors.primary),
                          label: Text(
                            'چسباندن کد از پیامک / حافظه',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Countdown timer
                      Center(
                        child: _canResend
                            ? TextButton(
                                onPressed: () {
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
                        onPressed: isLoading ? null : _submit,
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
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
