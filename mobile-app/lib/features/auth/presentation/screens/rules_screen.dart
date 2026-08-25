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
          isFa ? 'قوانین و شرایط استفاده' : 'Terms of Use',
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
                isFa ? 'قوانین و شرایط استفاده از برنامه' : 'Terms of Use',
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isFa 
                    ? 'شرایط و ضوابط استفاده از سامانه و محتواهای آموزشی:'
                    : 'Terms and conditions for using the software and educational content:',
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
            ],
          ),
        ),
      ),
    );
  }
}
