import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/player.dart';

/// Профіль і матчі гравця. Бекенд команди тут не потрібен: OpenDota публічний.
abstract interface class ProfileRepository {
  Future<PlayerProfile> fetchProfile(int accountId);
  Future<List<PlayerMatch>> fetchMatches(int accountId, ProfilePeriod period);
}

/// `https://api.opendota.com/api/players/…`.
class OpenDotaProfileRepository implements ProfileRepository {
  OpenDotaProfileRepository(this._dio);

  static const base = 'https://api.opendota.com/api';

  /// Поля матчу, яких OpenDota за замовчуванням не віддає (GPM, XPM).
  static const _fields = [
    'match_id', 'player_slot', 'radiant_win', 'duration', 'start_time', 'hero_id',
    'kills', 'deaths', 'assists', 'gold_per_min', 'xp_per_min',
  ];

  final Dio _dio;
  int? _latestPatch;

  @override
  Future<PlayerProfile> fetchProfile(int accountId) async {
    final (player, wl) = await (_get('/players/$accountId'), _get('/players/$accountId/wl')).wait;
    return PlayerProfile.fromOpenDota(accountId, jsonObject(player), jsonObject(wl));
  }

  @override
  Future<List<PlayerMatch>> fetchMatches(int accountId, ProfilePeriod period) async {
    final query = <String, Object>{
      'project': _fields,
      ...switch (period) {
        ProfilePeriod.last25 => {'limit': 25},
        ProfilePeriod.last100 => {'limit': 100},
        ProfilePeriod.week => {'date': 7},
        ProfilePeriod.month => {'date': 30},
        ProfilePeriod.patch => {'patch': await _patchId()},
      },
    };
    final data = await _get('/players/$accountId/matches', query);
    return [for (final m in jsonList(data)) PlayerMatch.fromOpenDota(m)];
  }

  /// Номер поточного патча в OpenDota (останній у `/constants/patch`).
  Future<int> _patchId() async {
    final cached = _latestPatch;
    if (cached != null) return cached;
    final patches = jsonList(await _get('/constants/patch'));
    if (patches.isEmpty) throw const ApiException(ApiFailure.server, code: 'no_patches');
    return _latestPatch = (patches.last['id'] as num).toInt();
  }

  Future<Object?> _get(String path, [Map<String, Object>? query]) async {
    try {
      final response = await _dio.get<Object>(
        '$base$path',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
