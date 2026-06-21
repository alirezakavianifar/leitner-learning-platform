import 'package:mobile_app/core/network/dio_client.dart';

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
  String get providerName => 'DIRECT';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    try {
      final transactionId = 'DIR.mock-${DateTime.now().millisecondsSinceEpoch}';
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
