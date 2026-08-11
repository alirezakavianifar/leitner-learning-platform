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
                    isFa ? 'قوانین و مقررات سیستم' : 'Terms & System Rules',
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFa
                        ? 'لطفا قوانین و مقررات تکرار فاصله‌دار سامانه را قبل از ادامه مطالعه و تایید کنید:'
                        : 'Please review and accept our platform\'s spaced repetition rules before continuing:',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Rules List Card
                  Expanded(
                    child: Card(
                      color: AppColors.surfaceWithOpacity,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildRuleItem(
                            context,
                            isFa ? '۱. قانون عدم انجام مرور (قانون A)' : '1. Overdue Reset Rule (Rule A)',
                            isFa
                                ? 'اگر یک فلش‌کارت آماده مرور شود و در همان روز آن را مطالعه نکنید، پیشرفت آن ریست شده و به خانه اول (جعبه ۱) بازمی‌گردد.'
                                : 'If a flashcard becomes due for review and you do not study it on that day, its progression resets, and it is returned back to Box 1.',
                          ),
                          _buildRuleItem(
                            context,
                            isFa ? '۲. قانون مرور در صفحه نشان‌شده‌ها (قانون B)' : '2. Favorites View Reset Rule (Rule B)',
                            isFa
                                ? 'دیدن یا مرور کارت در صفحه نشان‌شده‌ها، پیام تایید امنیتی نشان می‌دهد. پس از تایید، پیشرفت کارت در لایتنر ریست شده و به جعبه ۱ برمی‌گردد.'
                                : 'Viewing or reviewing a card inside the "Favorites" screen will prompt a safety confirmation. Upon confirmation, its Leitner box progress resets back to Box 1.',
                          ),
                          _buildRuleItem(
                            context,
                            isFa ? '۳. قانون دسترسی مستقیم به کارت (قانون C)' : '3. Direct Access Reset Rule (Rule C)',
                            isFa
                                ? 'جستجو یا وارد کردن مستقیم شماره کارت و باز کردن آن، پیام تایید امنیتی نشان می‌دهد. پس از تایید، پیشرفت کارت ریست شده و به جعبه ۱ برمی‌گردد.'
                                : 'Jumping directly to any card by searching or entering its specific card number will show a safety confirmation. Upon confirmation, its progress resets back to Box 1.',
                          ),
                          _buildRuleItem(
                            context,
                            isFa ? '۴. حافظه موقت آفلاین و اعتبارسنجی' : '4. Offline Caching & Validation',
                            isFa
                                ? 'امکان دانلود دوره‌ها و مطالعه آن‌ها به صورت آفلاین وجود دارد. برنامه باید حداقل هر ۲۴ ساعت یک‌بار به سرور متصل شود تا بنرها و اعلانات جدید را دریافت کند.'
                                : 'You can download and learn courses offline. The app must periodically query the server (approximately once every 24 hours) to update announcements and banners.',
                          ),
                          _buildRuleItem(
                            context,
                            isFa ? '۵. واترمارک ضد سرقت محتوا' : '5. Anti-Piracy Watermarking',
                            isFa
                                ? 'جهت حفظ حقوق ناشران و تولیدکنندگان محتوا، واترمارک‌های پیدا و پنهان شامل مشخصات شناسه کاربری شما روی محتوای آموزشی دوره‌ها رندر می‌شود.'
                                : 'To discourage piracy and protect content creators, visible and invisible watermarks containing user identifiers are rendered across course study materials.',
                          ),
                        ],
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
                                ? 'قوانین یادگیری لایتنر و راهنمای برنامه را مطالعه کردم و می‌پذیرم.'
                                : 'I read and accept all the Leitner learning rules and platform guidelines.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
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

  Widget _buildRuleItem(BuildContext context, String title, String body) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
