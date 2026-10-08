import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../config/app_config.dart';

/// Позначка для запитів, які вимагають токена (у `openapi.yaml` —
/// `security: BearerAuth`, зараз це лише `/admin/sync`).
/// Мета й герої публічні, тож без зайвого заголовка й CORS-preflight.
Options authorized([Options? options]) =>
    (options ?? Options()).copyWith(extra: {...?options?.extra, _authKey: true});

const _authKey = 'auth';

final dioProvider = Provider<Dio>((ref) {
  const timeout = Duration(seconds: 10);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: timeout,
      sendTimeout: timeout,
      receiveTimeout: timeout,
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(_AuthInterceptor(ref));
  ref.onDispose(dio.close);
  return dio;
});

/// Додає `Authorization: Bearer …` до захищених запитів, а на їхній 401
/// закриває сесію — роутер сам поверне на екран входу.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[_authKey] == true) {
      final token = _ref.read(authControllerProvider).session?.token;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 && err.requestOptions.extra[_authKey] == true) {
      _ref.read(authControllerProvider.notifier).signOut();
    }
    handler.next(err);
  }
}

enum ApiFailure {
  /// Немає мережі, таймаут 10 с, сервер недосяжний.
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
      >= 500 => ApiFailure.server,
      _ => ApiFailure.server,
    };
    return ApiException(failure, statusCode: status, code: code);
  }

  final ApiFailure failure;
  final int? statusCode;
  final String? code;

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

String? _errorCode(Object? data) {
  try {
    final body = data is String ? jsonDecode(data) : data;
    return body is Map ? body['error']?.toString() : null;
  } catch (_) {
    return null;
  }
}
