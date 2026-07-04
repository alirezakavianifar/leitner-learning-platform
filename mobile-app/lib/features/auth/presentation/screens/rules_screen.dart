import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isFa ? 'قوانین و مقررات سیستم' : 'Rules & Guidelines',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isFa ? 'مقررات جعبه لایتنر' : 'Terms & System Rules',
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isFa 
                    ? 'قوانین و مقررات تکرار فاصله‌دار سامانه یادگیری لایتنر به شرح زیر است:'
                    : 'Leitner spaced repetition learning rules and platform guidelines:',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  color: AppColors.surface.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border),
                  ),
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
            ],
          ),
        ),
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
