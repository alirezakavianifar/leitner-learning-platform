import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'profile_completion_screen.dart';
import 'home_hub_screen.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/error/error_formatter.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  final String mobileNumber;
  final String token;
  final String refreshToken;

  const TermsAcceptanceScreen({
    Key? key,
    required this.mobileNumber,
    required this.token,
    required this.refreshToken,
  }) : super(key: key);

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _isAccepted = false;

  void _submit() {
    if (_isAccepted) {
      context.read<AuthBloc>().add(
            AcceptTermsEvent(
              mobileNumber: widget.mobileNumber,
              token: widget.token,
              refreshToken: widget.refreshToken,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is ProfilePendingState) {
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isFa ? 'قوانین و شرایط استفاده' : 'Terms of Use',
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFa
                        ? 'لطفا قوانین و شرایط استفاده از برنامه را قبل از ادامه مطالعه و تایید فرمایید:'
                        : 'Please review and accept our platform\'s terms of use before continuing:',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Terms Card
                  Expanded(
                    child: Card(
                      color: AppColors.surfaceWithOpacity,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.gavel_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isFa ? 'متن قوانین و شرایط استفاده' : 'Terms & Conditions',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              isFa
                                  ? 'کلیه حقوق مادی و معنوی این نرم افزار و محتواهای آموزشی آن متعلق به مالک آن میباشد. هرگونه کپی برداری و دخل و تصرف در نرم افزار و محتواهای آن قانونا و شرعا غیر مجاز و قابل پیگرد میباشد. لطفا دقت بفرمایید،واریزهای انجام شده قابل عودت نمیباشد. برای رفع مشکلات،ارائه انتقاد و پیشنهادات با اکانت ادمین پشتیبانی در تماس باشید.'
                                  : 'All intellectual and material property rights of this software and its educational contents belong to its owner. Any copying, reproduction, or unauthorized alteration of the software and its contents is legally prohibited and subject to prosecution. Please note that completed payments are non-refundable. For troubleshooting, criticisms, and suggestions, please contact the admin support account.',
                              style: textTheme.bodyLarge?.copyWith(
                                color: AppColors.textPrimary,
                                height: 2.0,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Acceptance checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _isAccepted,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          setState(() {
                            _isAccepted = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isAccepted = !_isAccepted;
                            });
                          },
                          child: Text(
                            isFa
                                ? 'قوانین و شرایط استفاده از برنامه را مطالعه کردم و می‌پذیرم.'
                                : 'I have read and accept the terms of use.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action button
                  ElevatedButton(
                    onPressed: (_isAccepted && !isLoading) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
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
                            isFa ? 'تایید و ادامه' : 'Accept and Continue',
                            style: textTheme.titleLarge?.copyWith(
                              color: _isAccepted ? Colors.white : Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
