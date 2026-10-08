import 'dart:math';

import 'package:backend/auth/jwt_service.dart';
import 'package:backend/auth/password_hasher.dart';
import 'package:backend/db/app_database.dart';

/// A rejected auth request: HTTP status plus an error code the client can branch on.
class AuthError implements Exception {
  AuthError(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'AuthError($status, $code)';
}

/// Register/login for /api/auth/* (AuthResponse in docs/openapi.yaml) and Bearer checks.
class AuthService {
  AuthService(this._db, this._jwt, this._hasher);

  /// Same rules as the Flutter form (mobile AuthValidators).
  static const minPasswordLength = 6;
  static const maxPasswordLength = 128;
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final AppDatabase _db;
  final JwtService _jwt;
  final PasswordHasher _hasher;
  final _random = Random.secure();

  /// Compared against when the email is unknown, so login takes the same time either way.
  late final String _dummyHash = _hasher.hash('not-a-real-password');

  /// Throws [AuthError] 400: invalid_email, password_too_short, password_too_long, email_taken.
  Map<String, Object?> register(String email, String password) {
    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) throw AuthError(400, 'invalid_email');
    if (password.length < minPasswordLength) throw AuthError(400, 'password_too_short');
    if (password.length > maxPasswordLength) throw AuthError(400, 'password_too_long');
    if (_db.findUserByEmail(normalized) != null) throw AuthError(400, 'email_taken');

    final id = 'usr_${List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    _db.createUser(id: id, email: normalized, passwordHash: _hasher.hash(password));
    return _authResponse(id, normalized);
  }

  /// Throws [AuthError] 401 invalid_credentials for an unknown email or a wrong password.
  Map<String, Object?> login(String email, String password) {
    final user = _db.findUserByEmail(email.trim().toLowerCase());
    final matches = _hasher.verify(password, user?.passwordHash ?? _dummyHash);
    if (user == null || !matches) throw AuthError(401, 'invalid_credentials');
    return _authResponse(user.id, user.email);
  }

  /// User id from an `Authorization: Bearer <jwt>` header, or null when it's missing or invalid.
  String? userIdFromHeader(String? authorization) {
    if (authorization == null || !authorization.startsWith('Bearer ')) return null;
    return _jwt.verify(authorization.substring('Bearer '.length).trim())?['sub'] as String?;
  }

  Map<String, Object?> _authResponse(String id, String email) => {
        'token': _jwt.sign({'sub': id, 'email': email}),
        'user': {'id': id, 'email': email},
      };
}
