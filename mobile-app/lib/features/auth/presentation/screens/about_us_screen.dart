import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';
import 'package:mobile_app/core/constants/app_icon_sizes.dart';
import '../widgets/social_messenger_tile.dart';
import 'support_screen.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.aboutUs,
          style: textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: BlocBuilder<ConfigBloc, ConfigState>(
            builder: (context, state) {
              final RemoteConfig? config = state.config;
              final double logoSize = AppIconSizes.getAppLogoSize(config);
              final double borderRadius = (logoSize * 0.25).clamp(16.0, 36.0);
              final telegramUrl = config?.telegramUrl ?? 'https://t.me/RightlearnApp';
              final baleUrl = config?.baleUrl ?? 'https://ble.ir/rightlearnapp';
              final eitaaUrl = config?.eitaaUrl ?? 'https://eitaa.com/RightLearnApp';
              final supportUrl = config?.supportUrl ?? 'https://t.me/RLAppSupport';
              final supportId = config?.supportId ?? '@RLAppSupport';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.primary,
                            child: Icon(Icons.school, size: logoSize * 0.5, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFa ? 'رایت لرن' : 'RightLearn',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFa
                        ? 'درباره تیم تولید و اهداف رایت لرن'
                        : 'About our development team and educational mission',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      color: AppColors.surface.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(18.0),
                        children: [
                          // 1. Mission Section
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
                          const SizedBox(height: 20),

                          // 2. Development Team Section
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

                          // 3. Messenger Channels Section
                          Row(
                            children: [
                              Icon(Icons.hub_rounded, color: AppColors.secondary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isFa ? 'آدرس ما در پیام‌رسان‌ها' : 'Our Messengers & Social Channels',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.messengersDesc,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 12),

                          // Telegram Tile
                          SocialMessengerTile(
                            type: MessengerType.telegram,
                            title: isFa ? 'کانال تلگرام' : 'Telegram Channel',
                            subtitle: telegramUrl,
                            url: telegramUrl,
                          ),

                          // Bale Tile
                          SocialMessengerTile(
                            type: MessengerType.bale,
                            title: isFa ? 'کانال بله' : 'Bale Channel',
                            subtitle: baleUrl,
                            url: baleUrl,
                          ),

                          // Eitaa Tile
                          SocialMessengerTile(
                            type: MessengerType.eitaa,
                            title: isFa ? 'کانال ایتا' : 'Eitaa Channel',
                            subtitle: eitaaUrl,
                            url: eitaaUrl,
                          ),

                          const SizedBox(height: 20),

                          // 4. Support Section
                          Row(
                            children: [
                              Icon(Icons.support_agent_rounded, color: AppColors.secondary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isFa ? 'پشتیبانی' : 'Support & Help Desk',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Direct Support Handle Tile
                          SocialMessengerTile(
                            type: MessengerType.support,
                            title: isFa ? 'پشتیبانی تلگرام ($supportId)' : 'Telegram Support ($supportId)',
                            subtitle: supportUrl,
                            url: supportUrl,
                          ),
                          const SizedBox(height: 12),

                          // In-app Support Page Navigation Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.85),
                                  AppColors.secondary.withOpacity(0.85),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SupportScreen()),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 22),
                                      const SizedBox(width: 10),
                                      Text(
                                        loc.supportPageBtn,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
