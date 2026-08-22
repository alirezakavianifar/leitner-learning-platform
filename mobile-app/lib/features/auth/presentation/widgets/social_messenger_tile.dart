import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

enum MessengerType {
  telegram,
  bale,
  eitaa,
  support,
}

class SocialMessengerTile extends StatelessWidget {
  final MessengerType type;
  final String title;
  final String subtitle;
  final String url;
  final bool isSecondaryAction;

  const SocialMessengerTile({
    Key? key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.url,
    this.isSecondaryAction = false,
  }) : super(key: key);

  Color get _brandColor {
    switch (type) {
      case MessengerType.telegram:
        return const Color(0xFF24A1DE);
      case MessengerType.bale:
        return const Color(0xFF00B18F);
      case MessengerType.eitaa:
        return const Color(0xFFE56717);
      case MessengerType.support:
        return const Color(0xFF6B4EE6);
    }
  }

  Widget _buildBrandIcon() {
    switch (type) {
      case MessengerType.telegram:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF24A1DE).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        );

      case MessengerType.bale:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00C8A0), Color(0xFF009678)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B18F).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        );

      case MessengerType.eitaa:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFF07E26), Color(0xFFD6560B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE56717).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        );

      case MessengerType.support:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6B4EE6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B4EE6).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        );
    }
  }

  Future<void> _openLink(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.openLinkError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.openLinkError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _brandColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openLink(context),
          splashColor: _brandColor.withOpacity(0.15),
          highlightColor: _brandColor.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Clickable custom brand icon
                GestureDetector(
                  onTap: () => _openLink(context),
                  child: _buildBrandIcon(),
                ),
                const SizedBox(width: 14),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Arrow Icon Button
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: _brandColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
