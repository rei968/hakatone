import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:backend/auth/password_hasher.dart';

/// Minimal HS256 JWT for our own tokens: sign on login, verify on protected routes.
class JwtService {
  JwtService(String secret, {this.ttl = const Duration(days: 7)}) : _hmac = Hmac(sha256, utf8.encode(secret));

  /// Uses [secret] (JWT_SECRET) when set; otherwise a random per-process secret,
  /// so issued tokens stop working after a restart.
  factory JwtService.fromEnv(String? secret) {
    if (secret != null && secret.isNotEmpty) return JwtService(secret);
    print('JWT_SECRET is not set: using a random secret, tokens reset on restart');
    final random = Random.secure();
    return JwtService(base64.encode(List<int>.generate(32, (_) => random.nextInt(256))));
  }

  final Hmac _hmac;
  final Duration ttl;

  String sign(Map<String, Object?> claims) {
    final now = _nowSeconds();
    final header = _encode({'alg': 'HS256', 'typ': 'JWT'});
    final payload = _encode({...claims, 'iat': now, 'exp': now + ttl.inSeconds});
    return '$header.$payload.${_signature('$header.$payload')}';
  }

  /// Claims of a token with a valid signature that hasn't expired; null otherwise.
  Map<String, dynamic>? verify(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final expected = _signature('${parts[0]}.${parts[1]}');
    if (!constantTimeEquals(utf8.encode(expected), utf8.encode(parts[2]))) return null;

    try {
      final header = _decode(parts[0]);
      final claims = _decode(parts[1]);
      if (header['alg'] != 'HS256') return null;
      final exp = claims['exp'];
      if (exp is! int || exp <= _nowSeconds()) return null;
      return claims;
    } catch (_) {
      return null;
    }
  }

  String _signature(String data) => _base64Url(_hmac.convert(utf8.encode(data)).bytes);
}

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _base64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _encode(Map<String, Object?> json) => _base64Url(utf8.encode(jsonEncode(json)));

Map<String, dynamic> _decode(String part) =>
    jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part)))) as Map<String, dynamic>;
