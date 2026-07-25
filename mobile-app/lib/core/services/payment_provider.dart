import 'package:mobile_app/core/network/dio_client.dart';
import 'package:url_launcher/url_launcher.dart';


abstract class PaymentProvider {
  String get providerName;
  Future<bool> purchaseCourse(String courseId);
}

class GooglePlayPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  GooglePlayPaymentProvider(this.dioClient);

  @override
  String get providerName => 'GOOGLE_PLAY';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    try {
      final transactionId = 'GPA.mock-${DateTime.now().millisecondsSinceEpoch}';
      final response = await dioClient.dio.post('/purchases', data: {
        'course_id': courseId,
        'payment_provider': providerName,
        'transaction_id': transactionId,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class BazaarPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  BazaarPaymentProvider(this.dioClient);

  @override
  String get providerName => 'BAZAAR';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    try {
      final transactionId = 'BZ.mock-${DateTime.now().millisecondsSinceEpoch}';
      final response = await dioClient.dio.post('/purchases', data: {
        'course_id': courseId,
        'payment_provider': providerName,
        'transaction_id': transactionId,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class MyketPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  MyketPaymentProvider(this.dioClient);

  @override
  String get providerName => 'MYKET';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    try {
      final transactionId = 'MK.mock-${DateTime.now().millisecondsSinceEpoch}';
      final response = await dioClient.dio.post('/purchases', data: {
        'course_id': courseId,
        'payment_provider': providerName,
        'transaction_id': transactionId,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          return launched;
        }
      }
      return false;
    } catch (e) {
      print('ZarinPal purchase exception: $e');
      return false;
    }
  }
}


