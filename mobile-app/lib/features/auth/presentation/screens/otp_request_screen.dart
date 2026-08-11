import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/localization/locale_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/core/error/error_formatter.dart';
import 'otp_verification_screen.dart';

class OtpRequestScreen extends StatefulWidget {
  const OtpRequestScreen({Key? key}) : super(key: key);

  @override
  State<OtpRequestScreen> createState() => _OtpRequestScreenState();
}

class _OtpRequestScreenState extends State<OtpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _captchaController = TextEditingController();
  
  String? _captchaId;
  String? _captchaSvgString;

  @override
  void initState() {
    super.initState();
    // Load initial CAPTCHA
    context.read<AuthBloc>().add(LoadCaptchaEvent());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _captchaId != null) {
      context.read<AuthBloc>().add(
            RequestOtpEvent(
              mobileNumber: _phoneController.text.trim(),
              captchaId: _captchaId!,
              captchaAnswer: _captchaController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpSentState) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(mobileNumber: state.mobileNumber),
              ),
            );
          } else if (state is CaptchaLoadedState) {
            setState(() {
              _captchaId = state.captchaId;
              
              // Extract the base64 part from the data URL format: "data:image/svg+xml;base64,..."
              final commaIndex = state.imageBase64.indexOf(',');
              if (commaIndex != -1) {
                final base64Data = state.imageBase64.substring(commaIndex + 1);
                _captchaSvgString = utf8.decode(base64.decode(base64Data));
              } else {
                _captchaSvgString = null;
              }
            });
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
            // Refresh CAPTCHA on failure
            context.read<AuthBloc>().add(LoadCaptchaEvent());
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoadingState;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language Switcher Toggle
                      Align(
                        alignment: Alignment.topRight,
                        child: BlocBuilder<LocaleBloc, LocaleState>(
                          builder: (context, localeState) {
                            final isPersian = localeState.locale.languageCode == 'fa';
                            return TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.surfaceWithOpacity,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: Icon(Icons.language, color: AppColors.primary, size: 20),
                              label: Text(
                                isPersian ? 'English' : 'فارسی',
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                final newLocale = isPersian ? const Locale('en') : const Locale('fa');
                                context.read<LocaleBloc>().add(ChangeLocaleEvent(newLocale));
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Branding
                      Text(
                        loc.appTitle,
                        style: textTheme.displayMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.enterMobileOtp,
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Mobile input field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: loc.mobileNumber,
                          hintText: '09123456789',
                          prefixIcon: Icon(Icons.phone_android, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.pleaseEnterMobileNumber;
                          }
                          // Validate basic format matching Iranian mobile patterns
                          final clean = value.replaceAll(' ', '');
                          if (!RegExp(r'^(\+98|0)?9\d{9}$').hasMatch(clean)) {
                            return loc.enterValidIranianMobile;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // CAPTCHA display & entry
                      Card(
                        margin: EdgeInsets.zero,
                        color: AppColors.surfaceWithOpacity,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: _captchaSvgString != null
                                          ? Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: SvgPicture.string(
                                                _captchaSvgString!,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: Icon(Icons.refresh, color: AppColors.secondary),
                                    tooltip: loc.refreshCaptcha,
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            context.read<AuthBloc>().add(LoadCaptchaEvent());
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _captchaController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  labelText: loc.captchaAnswer,
                                  hintText: '?',
                                  prefixIcon: Icon(Icons.security, color: AppColors.textSecondary),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return loc.pleaseEnterCaptcha;
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit button
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
                                loc.sendVerificationCode,
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
