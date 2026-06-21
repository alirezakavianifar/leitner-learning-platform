import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Standard PBKDF2-HMAC-SHA256 implementation in pure Dart.
class Pbkdf2 {
  /// Derives a key of [keyLength] bytes using PBKDF2-HMAC-SHA256.
  static Uint8List deriveKey({
    required String password,
    required String salt,
    int iterations = 10000,
    int keyLength = 32, // default 256 bits
  }) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    
    final hmac = Hmac(sha256, passwordBytes);
    final numBlocks = (keyLength + 31) ~/ 32;
    final result = BytesBuilder();

    for (int blockNum = 1; blockNum <= numBlocks; blockNum++) {
      final blockIndexBytes = Uint8List(4);
      blockIndexBytes[0] = (blockNum >> 24) & 0xff;
      blockIndexBytes[1] = (blockNum >> 16) & 0xff;
      blockIndexBytes[2] = (blockNum >> 8) & 0xff;
      blockIndexBytes[3] = blockNum & 0xff;

      final saltAndIndex = Uint8List(saltBytes.length + 4);
      saltAndIndex.setAll(0, saltBytes);
      saltAndIndex.setAll(saltBytes.length, blockIndexBytes);

      List<int> u = hmac.convert(saltAndIndex).bytes;
      final xorSum = List<int>.from(u);

      for (int iter = 2; iter <= iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (int i = 0; i < 32; i++) {
          xorSum[i] ^= u[i];
        }
      }

      result.add(xorSum);
    }

    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }
}
