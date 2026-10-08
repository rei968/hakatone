import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenDotaException implements Exception {
  OpenDotaException(this.message);

  final String message;

  @override
  String toString() => 'OpenDotaException: $message';
}

/// Thin HTTP client for the public OpenDota API.
class OpenDotaClient {
  OpenDotaClient({http.Client? httpClient, this.baseUrl = 'https://api.opendota.com/api'})
      : _http = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 30);

  final http.Client _http;
  final String baseUrl;
  Map<int, ({String name, int cost})>? _items;
  Map<String, String>? _itemNamesByKey;
  Map<String, dynamic>? _heroAbilities;
  Map<String, dynamic>? _abilities;
  Map<int, String>? _heroNpcNames;

  /// Name of the latest patch from GET /constants/patch (the last element), e.g. "7.41".
  Future<String> latestPatch() async {
    final data = await _get('/constants/patch');
    final last = data is List && data.isNotEmpty ? data.last : null;
    final name = last is Map ? last['name'] : null;
    if (name is! String || name.isEmpty) throw OpenDotaException('constants/patch: no patch name');
    return name;
  }

  /// GET /scenarios/itemTimings?hero_id=: rows `{item, time, games, wins}`, games/wins as strings.
  Future<List<Map<String, dynamic>>> itemTimings(int heroId) async {
    final data = await _get('/scenarios/itemTimings?hero_id=$heroId');
    if (data is! List) throw OpenDotaException('itemTimings: expected a JSON array');
    return data.cast<Map<String, dynamic>>();
  }

  /// GET /constants/hero_abilities: npc name -> {abilities: [...keys], talents: [{name, level}]}. Cached.
  Future<Map<String, dynamic>> heroAbilities() async =>
      _heroAbilities ??= await _getObject('/constants/hero_abilities');

  /// GET /constants/abilities: ability/talent key -> {dname, ...}. Cached (about 1.3 MB).
  Future<Map<String, dynamic>> abilities() async => _abilities ??= await _getObject('/constants/abilities');

  /// Hero id -> npc name ("npc_dota_hero_pudge") from GET /constants/heroes. Cached.
  Future<Map<int, String>> heroNpcNames() async => _heroNpcNames ??= {
        for (final hero in (await _getObject('/constants/heroes')).values.whereType<Map>())
          if (hero['id'] is int && hero['name'] is String) hero['id'] as int: hero['name'] as String,
      };

  /// Item key ("black_king_bar") -> display name ("Black King Bar"), from /constants/items.
  Future<Map<String, String>> itemNamesByKey() async {
    await items();
    return _itemNamesByKey!;
  }

  /// GET /heroStats: one entry per hero with pub_pick/pub_win, roles, base stats, img.
  Future<List<Map<String, dynamic>>> heroStats() async {
    final data = await _get('/heroStats');
    if (data is! List) throw OpenDotaException('/heroStats: expected a JSON array');
    return data.cast<Map<String, dynamic>>();
  }

  /// GET /heroes/{id}/itemPopularity: phase (start_game_items, early_game_items, ...)
  /// -> item id as a string -> purchase count.
  Future<Map<String, Map<String, int>>> itemPopularity(int heroId) async {
    final data = await _get('/heroes/$heroId/itemPopularity');
    if (data is! Map) throw OpenDotaException('itemPopularity: expected a JSON object');
    return {
      for (final MapEntry(:key, :value) in data.entries)
        key as String: (value as Map).map((id, count) => MapEntry(id as String, (count as num).toInt())),
    };
  }

  /// GET /heroes/{id}/matchups: [{hero_id, games_played, wins}], wins are this hero's.
  Future<List<Map<String, dynamic>>> matchups(int heroId) async {
    final data = await _get('/heroes/$heroId/matchups');
    if (data is! List) throw OpenDotaException('matchups: expected a JSON array');
    return data.cast<Map<String, dynamic>>();
  }

  /// Item id -> display name and cost, from /constants/items. Fetched once, then cached.
  Future<Map<int, ({String name, int cost})>> items() async {
    final cached = _items;
    if (cached != null) return cached;

    final data = await _getObject('/constants/items');
    _itemNamesByKey = {
      for (final MapEntry(:key, :value) in data.entries)
        if (value is Map && value['dname'] is String) key: value['dname'] as String,
    };
    return _items = {
      for (final item in data.values.whereType<Map<String, dynamic>>())
        if (item['id'] is int && item['dname'] is String)
          item['id'] as int: (name: item['dname'] as String, cost: (item['cost'] as num?)?.toInt() ?? 0),
    };
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final data = await _get(path);
    if (data is! Map<String, dynamic>) throw OpenDotaException('$path: expected a JSON object');
    return data;
  }

  Future<Object?> _get(String path) async {
    final response = await _http.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
    if (response.statusCode != 200) {
      throw OpenDotaException('GET $path -> HTTP ${response.statusCode}');
    }
    // Decode bytes explicitly: http falls back to latin1 when the charset header is missing.
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
