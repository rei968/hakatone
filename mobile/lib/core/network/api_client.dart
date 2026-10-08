import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Бекенд команди (`docs/openapi.yaml`). Мета й герої публічні, без токена.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      // Бекенд на Render засинає після ~15 хв і прокидається до хвилини,
      // а перший AI-білд героя Gemini складає до ~25 с.
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Для сторонніх публічних API з повними адресами: OpenDota (профіль гравця)
/// і Steam (перевірка входу).
final externalDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

enum ApiFailure {
  /// Немає мережі, таймаут, сервер недосяжний.
  network,

  /// 5xx.
  server,
  notFound,
  unauthorized,
  badRequest,
}

class ApiException implements Exception {
  const ApiException(this.failure, {this.statusCode, this.code});

  /// Переклад помилки dio. [code] — поле `error` з тіла відповіді бекенду
  /// (`{"error": "hero_not_found"}`).
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final code = _errorCode(e.response?.data);
    if (e.type != DioExceptionType.badResponse || status == null) {
      return const ApiException(ApiFailure.network);
    }
    final failure = switch (status) {
      400 => ApiFailure.badRequest,
      401 => ApiFailure.unauthorized,
      404 => ApiFailure.notFound,
      _ => ApiFailure.server,
    };
    return ApiException(failure, statusCode: status, code: code);
  }

  final ApiFailure failure;
  final int? statusCode;
  final String? code;

  bool get isOffline => failure == ApiFailure.network;

  @override
  String toString() => 'ApiException($failure, $statusCode, $code)';
}

/// Тіло відповіді як JSON-об’єкт: dio розбирає `application/json` сам,
/// а все інше лишає рядком.
Map<String, dynamic> jsonObject(Object? data) {
  final decoded = data is String ? jsonDecode(data) : data;
  if (decoded is Map<String, dynamic>) return decoded;
  throw const ApiException(ApiFailure.server, code: 'unexpected_body');
}

/// Те саме для відповіді-масиву.
List<Map<String, dynamic>> jsonList(Object? data) {
  final decoded = data is String ? jsonDecode(data) : data;
  if (decoded is List) return decoded.whereType<Map<String, dynamic>>().toList();
  throw const ApiException(ApiFailure.server, code: 'unexpected_body');
}

/// Помилка не з бекенду, а будь-яка: мережа dio теж вважається офлайном.
bool isOfflineError(Object? error) => switch (error) {
      ApiException(:final isOffline) => isOffline,
      DioException(type: != DioExceptionType.badResponse) => true,
      _ => false,
    };

String? _errorCode(Object? data) {
  try {
    final body = data is String ? jsonDecode(data) : data;
    return body is Map ? body['error']?.toString() : null;
  } catch (_) {
    return null;
  }
}
