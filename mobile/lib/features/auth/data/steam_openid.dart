import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

/// Вхід через Steam OpenID 2.0, як на Dotabuff: гравець вводить пароль на сторінці
/// Steam, Steam повертає браузер на [returnTo] з підписаним Steam ID, а застосунок
/// перехоплює цей перехід і перевіряє підпис запитом `check_authentication` до Steam.
class SteamOpenId {
  SteamOpenId(this._dio, {String? realm}) : realm = realm ?? _defaultRealm;

  static const endpoint = 'https://steamcommunity.com/openid/login';
  static const _ns = 'http://specs.openid.net/auth/2.0';
  static const _identifierSelect = 'http://specs.openid.net/auth/2.0/identifier_select';

  /// Steam показує цю адресу на сторінці входу («Увійти на …»), тому це сервер команди.
  static String get _defaultRealm {
    final api = Uri.tryParse(AppConfig.apiBaseUrl);
    return (api != null && api.hasScheme && api.host.isNotEmpty) ? api.origin : 'https://hakatone.onrender.com';
  }

  final Dio _dio;
  final String realm;

  /// Сторінку за цією адресою ніхто не відкриває: WebView перехоплює перехід на неї.
  String get returnTo => '$realm/auth/steam/return';

  Uri get loginUri => Uri.parse(endpoint).replace(queryParameters: {
        'openid.ns': _ns,
        'openid.mode': 'checkid_setup',
        'openid.return_to': returnTo,
        'openid.realm': realm,
        'openid.identity': _identifierSelect,
        'openid.claimed_id': _identifierSelect,
      });

  bool isCallback(String url) => url.startsWith(returnTo);

  /// Steam ID з відповіді Steam, ще без перевірки підпису. `null` — гравець скасував вхід
  /// або відповідь не від Steam.
  static String? claimedSteamId(Uri callback) {
    final params = callback.queryParameters;
    if (params['openid.mode'] != 'id_res' || params['openid.op_endpoint'] != endpoint) return null;
    final match = RegExp(r'^https://steamcommunity\.com/openid/id/(\d{17})$').firstMatch(params['openid.claimed_id'] ?? '');
    return match?.group(1);
  }

  /// Перевіряє підпис у самого Steam і повертає Steam ID. Кидає [SteamLoginException].
  Future<String> verify(Uri callback) async {
    final steamId = claimedSteamId(callback);
    if (steamId == null) throw const SteamLoginException(SteamLoginFailure.cancelled);
    if (!callback.toString().startsWith(returnTo)) throw const SteamLoginException(SteamLoginFailure.invalid);
    try {
      final response = await _dio.post<String>(
        endpoint,
        data: {...callback.queryParameters, 'openid.mode': 'check_authentication'},
        options: Options(contentType: Headers.formUrlEncodedContentType, responseType: ResponseType.plain),
      );
      if (!(response.data ?? '').contains('is_valid:true')) {
        throw const SteamLoginException(SteamLoginFailure.invalid);
      }
      return steamId;
    } on DioException {
      throw const SteamLoginException(SteamLoginFailure.network);
    }
  }
}

enum SteamLoginFailure { cancelled, invalid, network }

class SteamLoginException implements Exception {
  const SteamLoginException(this.failure);

  final SteamLoginFailure failure;

  @override
  String toString() => 'SteamLoginException($failure)';
}
