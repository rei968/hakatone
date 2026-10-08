import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 password hashes, stored as `pbkdf2_sha256$<iterations>$<salt>$<hash>` (base64).
class PasswordHasher {
  PasswordHasher({this.iterations = 20000});

  final int iterations;
  final _random = Random.secure();

  String hash(String password) {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final derived = pbkdf2Sha256(utf8.encode(password), salt, iterations);
    return 'pbkdf2_sha256\$$iterations\$${base64.encode(salt)}\$${base64.encode(derived)}';
  }

  bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1) return false;
    final actual = pbkdf2Sha256(utf8.encode(password), base64.decode(parts[2]), rounds);
    return constantTimeEquals(actual, base64.decode(parts[3]));
  }
}

/// PBKDF2 (RFC 8018) with HMAC-SHA256 and a single block, i.e. a 32-byte key.
List<int> pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = List<int>.of(block);
  for (var i = 1; i < iterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return result;
}

/// Compares without an early exit, so timing doesn't reveal how many bytes matched.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
