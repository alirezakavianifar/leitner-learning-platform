import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/security/pbkdf2.dart';

void main() {
  group('PBKDF2-HMAC-SHA256 Key Derivation Tests', () {
    test('Should derive key of specified length', () {
      final key = Pbkdf2.deriveKey(
        password: 'testPassword',
        salt: 'testSalt',
        iterations: 1000,
        keyLength: 32,
      );

      expect(key.length, 32);
    });

    test('Should be deterministic for same password, salt and iterations', () {
      final key1 = Pbkdf2.deriveKey(
        password: 'password123',
        salt: 'salt456',
        iterations: 1000,
        keyLength: 32,
      );

      final key2 = Pbkdf2.deriveKey(
        password: 'password123',
        salt: 'salt456',
        iterations: 1000,
        keyLength: 32,
      );

      expect(key1, key2);
    });

    test('Should derive different keys for different passwords or salts', () {
      final key1 = Pbkdf2.deriveKey(
        password: 'password123',
        salt: 'salt456',
        iterations: 1000,
        keyLength: 32,
      );

      final key2 = Pbkdf2.deriveKey(
        password: 'password999',
        salt: 'salt456',
        iterations: 1000,
        keyLength: 32,
      );

      final key3 = Pbkdf2.deriveKey(
        password: 'password123',
        salt: 'salt999',
        iterations: 1000,
        keyLength: 32,
      );

      expect(key1, isNot(equals(key2)));
      expect(key1, isNot(equals(key3)));
    });

    test('Should match expected output structure when hex encoded', () {
      final key = Pbkdf2.deriveKey(
        password: 'mySuperSecurePassword',
        salt: 'randomlyGeneratedSalt',
        iterations: 2000,
        keyLength: 32,
      );

      final hexKey = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hexKey.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hexKey), true);
    });
  });
}
