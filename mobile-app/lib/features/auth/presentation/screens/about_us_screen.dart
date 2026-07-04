import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

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
          isFa ? 'درباره ما' : 'About Us',
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
                isFa ? 'سامانه یادگیری لایتنر' : 'Leitner Learning Platform',
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isFa 
                    ? 'درباره تیم تولید و اهداف سامانه یادگیری لایتنر'
                    : 'About our development team and educational mission',
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
                    padding: const EdgeInsets.all(20.0),
                    children: [
                      Text(
                        isFa ? 'ماموریت ما' : 'Our Mission',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFa
                            ? 'هدف ما ایجاد بستری پویا و علمی با تکیه بر روش علمی تکرار فاصله‌دار لایتنر است تا فراگیران بتوانند به ساده‌ترین شکل ممکن، محتوای آموزشی را به حافظه بلندمدت خود بسپارند.'
                            : 'Our mission is to build a dynamic and scientific environment using the Leitner spaced repetition method, allowing students to seamlessly transfer educational materials into their long-term memory.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isFa ? 'تیم توسعه و پشتیبانی' : 'Development & Support Team',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFa
                            ? 'این سامانه توسط تیمی از متخصصین توسعه نرم‌افزار، طراحان رابط کاربری و مشاوران آموزشی طراحی و تولید شده است. ما همواره تلاش می‌کنیم تا بهترین تجربه کاربری و امن‌ترین بستر حفاظت از محتوا را برای شما فراهم سازیم.'
                            : 'This platform was designed and developed by a dedicated team of software engineers, UI/UX designers, and educational consultants. We continually strive to deliver the best learning experience while safeguarding content creators\' work.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isFa ? 'ارتباط با ما' : 'Contact Us',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFa
                            ? 'از طریق صفحه پشتیبانی و تیکت‌ها در تنظیمات برنامه می‌توانید به صورت مستقیم با تیم فنی در ارتباط باشید. نظرات و پیشنهادهای شما به ما در ارتقای کیفیت برنامه کمک خواهد کرد.'
                            : 'You can reach out to our support team directly via the Support and Tickets screen in the app. Your feedback is highly appreciated and helps us improve the learning platform.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
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
}
