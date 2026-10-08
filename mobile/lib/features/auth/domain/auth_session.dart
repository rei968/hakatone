import 'package:flutter/foundation.dart';

/// `AuthResponse.user` з `docs/openapi.yaml`.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(id: json['id'] as String, email: json['email'] as String);

  final String id;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'email': email};
}

/// `AuthResponse` з `docs/openapi.yaml`: JWT і користувач.
@immutable
class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String token;
  final AuthUser user;

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}

/// Чому не вдалося увійти чи зареєструватися. Тексти для гравця
/// задає екран (docs/design/02-auth.html, «Валідація і тексти помилок»).
enum AuthFailure {
  /// 401 на вході.
  invalidCredentials,

  /// 400 `email_taken`.
  emailTaken,

  /// 400 `invalid_email`.
  invalidEmail,

  /// 400 `password_too_short` (менше 6).
  passwordTooShort,

  /// 400 `password_too_long` (понад 128).
  passwordTooLong,

  /// Інший 400 (`invalid_body`).
  invalidData,

  /// Немає мережі або таймаут.
  network,

  /// 5xx.
  server,
}

class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException($failure)';
}
