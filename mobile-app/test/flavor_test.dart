import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/injection_container.dart';

void main() {
  group('AppConfig Flavor Tests', () {
    test('should return true for isPremium when flavor is premium', () {
      final config = AppConfig(flavor: 'premium');
      expect(config.flavor, 'premium');
      expect(config.isPremium, true);
    });

    test('should return false for isPremium when flavor is store', () {
      final config = AppConfig(flavor: 'store');
      expect(config.flavor, 'store');
      expect(config.isPremium, false);
    });

    test('should return false for isPremium when flavor is anything else', () {
      final config = AppConfig(flavor: 'custom');
      expect(config.flavor, 'custom');
      expect(config.isPremium, false);
    });
  });
}
