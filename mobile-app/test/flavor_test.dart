import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/core/services/payment_provider.dart';
import 'package:mobile_app/core/services/storage_service.dart';
import 'package:mobile_app/injection_container.dart';

class MockStorageService implements StorageService {
  @override
  Future<String?> readSecure(String key) async => null;
  @override
  Future<void> writeSecure(String key, String value) async {}
  @override
  Future<void> deleteSecure(String key) async {}
}

void main() {
  group('AppConfig Flavor Tests', () {
    test('should return true for isPremium and isDirect when flavor is premium', () {
      final config = AppConfig(flavor: 'premium');
      expect(config.flavor, 'premium');
      expect(config.isPremium, true);
      expect(config.isDirect, true);
      expect(config.isBazaar, false);
    });

    test('should return true for isBazaar when flavor is bazaar', () {
      final config = AppConfig(flavor: 'bazaar');
      expect(config.flavor, 'bazaar');
      expect(config.isBazaar, true);
      expect(config.isPremium, false);
    });

    test('should return true for isStore when flavor is store', () {
      final config = AppConfig(flavor: 'store');
      expect(config.flavor, 'store');
      expect(config.isStore, true);
      expect(config.isPremium, false);
    });
  });

  group('DioClient Platform Header Tests', () {
    test('should inject X-App-Platform header matching the configured flavor', () {
      final dioBazaar = Dio();
      final clientBazaar = DioClient(
        dio: dioBazaar,
        storageService: MockStorageService(),
        baseUrl: 'http://localhost/api/v1',
        flavor: 'bazaar',
      );
      expect(dioBazaar.options.headers['X-App-Platform'], 'bazaar');
      expect(clientBazaar.flavor, 'bazaar');

      final dioPremium = Dio();
      final clientPremium = DioClient(
        dio: dioPremium,
        storageService: MockStorageService(),
        baseUrl: 'http://localhost/api/v1',
        flavor: 'premium',
      );
      expect(dioPremium.options.headers['X-App-Platform'], 'premium');
      expect(clientPremium.flavor, 'premium');
    });
  });

  group('BazaarPaymentProvider Security Tests', () {
    test('BazaarPaymentProvider strictly denies mock purchases without verified token', () async {
      final dio = Dio();
      final client = DioClient(
        dio: dio,
        storageService: MockStorageService(),
        baseUrl: 'http://localhost/api/v1',
        flavor: 'bazaar',
      );
      final provider = BazaarPaymentProvider(client);

      final courseResult = await provider.purchaseCourse('course-123');
      expect(courseResult, false);

      final packageResult = await provider.purchasePackage('package-123');
      expect(packageResult, false);
    });
  });
}
