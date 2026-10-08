import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import 'auth_repository.dart';

/// `POST /api/auth/login` і `/api/auth/register` на бекенді команди.
class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AuthSession> login({required String email, required String password}) =>
      _post('/api/auth/login', email, password, isRegistration: false);

  @override
  Future<AuthSession> register({required String email, required String password}) =>
      _post('/api/auth/register', email, password, isRegistration: true);

  Future<AuthSession> _post(String path, String email, String password, {required bool isRegistration}) async {
    try {
      final response = await _dio.post<Object>(path, data: {'email': email, 'password': password});
      return AuthSession.fromJson(jsonObject(response.data));
    } on DioException catch (e) {
      throw AuthException(_failure(ApiException.fromDio(e), isRegistration: isRegistration));
    } on ApiException {
      throw const AuthException(AuthFailure.server);
    }
  }

  /// За контрактом 400 реєстрації — «невалідні дані або email зайнятий».
  /// Дані ми вже перевірили до надсилання, тож 400 без коду вважаємо
  /// зайнятим email. Код `invalid_data` у тілі розрізняє ці випадки.
  static AuthFailure _failure(ApiException e, {required bool isRegistration}) => switch (e.failure) {
        ApiFailure.network => AuthFailure.network,
        ApiFailure.unauthorized => AuthFailure.invalidCredentials,
        ApiFailure.badRequest when isRegistration && e.code != 'invalid_data' => AuthFailure.emailTaken,
        ApiFailure.badRequest => AuthFailure.invalidData,
        ApiFailure.notFound || ApiFailure.server => AuthFailure.server,
      };
}
