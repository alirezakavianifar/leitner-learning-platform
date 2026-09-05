import 'package:mobile_app/core/network/dio_client.dart';
import 'package:url_launcher/url_launcher.dart';


abstract class PaymentProvider {
  String get providerName;
  Future<bool> purchaseCourse(String courseId);
  Future<bool> purchasePackage(String packageId);
}

class GooglePlayPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  GooglePlayPaymentProvider(this.dioClient);

  @override
  String get providerName => 'GOOGLE_PLAY';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    // Requires real Google Play Billing verification token
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId) async {
    // Requires real Google Play Billing verification token
    return false;
  }
}

class BazaarPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  BazaarPaymentProvider(this.dioClient);

  @override
  String get providerName => 'BAZAAR';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    // In-app purchases on Cafe Bazaar require verified Bazaar IAB purchase tokens.
    // Mock auto-complete is strictly disabled to prevent unauthorized downloads.
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId) async {
    return false;
  }
}

class MyketPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  MyketPaymentProvider(this.dioClient);

  @override
  String get providerName => 'MYKET';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId) async {
    return false;
  }
}

class DirectPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  DirectPaymentProvider(this.dioClient);

  @override
  String get providerName => 'ZARINPAL';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    try {
      final response = await dioClient.dio.post('/purchases/zarinpal/request', data: {
        'course_id': courseId,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['already_purchased'] == true) {
          return true;
        }

        final paymentUrl = data['payment_url'] as String?;
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final uri = Uri.parse(paymentUrl);
          bool launched = false;
          try {
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          if (!launched) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          return launched;
        }
      }
      return false;
    } catch (e) {
      print('ZarinPal purchase exception: $e');
      return false;
    }
  }

  @override
  Future<bool> purchasePackage(String packageId) async {
    try {
      final response = await dioClient.dio.post('/purchases/zarinpal/package-request', data: {
        'package_id': packageId,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['already_purchased'] == true) {
          return true;
        }

        final paymentUrl = data['payment_url'] as String?;
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final uri = Uri.parse(paymentUrl);
          bool launched = false;
          try {
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          if (!launched) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          return launched;
        }
      }
      return false;
    } catch (e) {
      print('ZarinPal package purchase exception: $e');
      return false;
    }
  }
}


