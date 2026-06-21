import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/security/pbkdf2.dart';

void main() {
  group('PBKDF2 Cryptography Tests', () {
    test('Should derive a consistent 32-byte key from password and salt', () {
      final password = 'device-unique-identifier-spec-2026';
      final salt = 'user-salt-random-hex-string';

      final key1 = Pbkdf2.deriveKey(
        password: password,
        salt: salt,
        iterations: 10, // low iterations for fast test runs
        keyLength: 32,
      );

      final key2 = Pbkdf2.deriveKey(
        password: password,
        salt: salt,
        iterations: 10,
        keyLength: 32,
      );

      // Verify length
      expect(key1.length, 32);
      
      // Verify consistency
      expect(key1, key2);

      // Verify that different password/salt yields different key
      final keyDifferent = Pbkdf2.deriveKey(
        password: 'different-password',
        salt: salt,
        iterations: 10,
        keyLength: 32,
      );
      expect(key1, isNot(equals(keyDifferent)));
    });

    test('Should match standard expected output representation length', () {
      final keyBytes = Pbkdf2.deriveKey(
        password: 'test',
        salt: 'salt',
        iterations: 1,
        keyLength: 16,
      );
      expect(keyBytes.length, 16);
    });
  });
}
