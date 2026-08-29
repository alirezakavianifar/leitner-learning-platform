import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:mobile_app/core/diagnostics/app_logger.dart';

/// Service implementing [SmsRetriever] interface for [Pinput] widget.
/// Leverages Google Play Services User Consent API & SMS Retriever API on Android,
/// allowing automatic incoming SMS OTP detection and autofill with zero intrusive permissions.
class SmsRetrieverService implements SmsRetriever {
  final SmartAuth _smartAuth;
  final bool useUserConsentApi;
  final String? senderPhoneNumber;

  SmsRetrieverService({
    SmartAuth? smartAuth,
    this.useUserConsentApi = true,
    this.senderPhoneNumber,
  }) : _smartAuth = smartAuth ?? SmartAuth.instance;

  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    // Only Android uses Google Play Services SMS retrieval APIs.
    // iOS handles OTP autofill natively via [AutofillHints.oneTimeCode].
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    try {
      AppLogger().info('Starting SMS retrieval listener (useUserConsentApi: $useUserConsentApi)...');
      
      final res = useUserConsentApi
          ? await _smartAuth.getSmsWithUserConsentApi(senderPhoneNumber: senderPhoneNumber)
          : await _smartAuth.getSmsWithRetrieverApi();

      if (res.hasData && res.data?.code != null && res.data!.code!.isNotEmpty) {
        AppLogger().info('SMS code detected successfully via SmartAuth.');
        return res.data!.code;
      } else {
        AppLogger().info('SMS retrieval completed without code: hasData=${res.hasData}');
        return null;
      }
    } catch (e, stack) {
      AppLogger().error('Error during SMS retrieval: $e', e, stack);
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (useUserConsentApi) {
        await _smartAuth.removeUserConsentApiListener();
      } else {
        await _smartAuth.removeSmsRetrieverApiListener();
      }
      AppLogger().info('SMS retriever listener disposed.');
    } catch (e) {
      AppLogger().error('Error disposing SMS listener: $e');
    }
  }
}
