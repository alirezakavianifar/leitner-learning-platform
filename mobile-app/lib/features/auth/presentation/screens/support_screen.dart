import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import '../widgets/social_messenger_tile.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitSupport() {
    if (!_formKey.currentState!.validate()) return;
    
    final loc = AppLocalizations.of(context);
    setState(() => _isSending = true);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.supportSubmittedMsg),
            backgroundColor: AppColors.secondary,
          ),
        );
        _messageController.clear();
        _emailController.clear();
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
          loc.support,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Direct Messengers & Support
              BlocBuilder<ConfigBloc, ConfigState>(
                builder: (context, state) {
                  final config = state.config;
                  final supportUrl = config?.supportUrl ?? 'https://t.me/RLAppSupport';
                  final supportId = config?.supportId ?? '@RLAppSupport';
                  final telegramUrl = config?.telegramUrl ?? 'https://t.me/RightlearnApp';
                  final baleUrl = config?.baleUrl ?? 'https://ble.ir/rightlearnapp';
                  final eitaaUrl = config?.eitaaUrl ?? 'https://eitaa.com/RightLearnApp';
                  final isFa = Localizations.localeOf(context).languageCode == 'fa';

                  return Column(
                    children: [
                      SocialMessengerTile(
                        type: MessengerType.support,
                        title: isFa ? 'پشتیبانی سریع در تلگرام ($supportId)' : 'Fast Telegram Support ($supportId)',
                        subtitle: supportUrl,
                        url: supportUrl,
                      ),
                      SocialMessengerTile(
                        type: MessengerType.telegram,
                        title: isFa ? 'کانال اطلاع‌رسانی تلگرام' : 'Official Telegram Channel',
                        subtitle: telegramUrl,
                        url: telegramUrl,
                      ),
                      SocialMessengerTile(
                        type: MessengerType.bale,
                        title: isFa ? 'کانال اطلاع‌رسانی بله' : 'Official Bale Channel',
                        subtitle: baleUrl,
                        url: baleUrl,
                      ),
                      SocialMessengerTile(
                        type: MessengerType.eitaa,
                        title: isFa ? 'کانال اطلاع‌رسانی ایتا' : 'Official Eitaa Channel',
                        subtitle: eitaaUrl,
                        url: eitaaUrl,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              Text(
                loc.submitATicket,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Email input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: loc.contactEmail,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return loc.contactEmailRequired;
                  if (!val.contains('@')) return loc.enterValidEmail;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message input
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: loc.howCanWeHelp,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  alignLabelWithHint: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return loc.messageRequired;
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSending ? null : _submitSupport,
                child: _isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(loc.submitTicket, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
