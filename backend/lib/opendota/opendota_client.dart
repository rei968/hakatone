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

    final data = await _get('/constants/items');
    if (data is! Map) throw OpenDotaException('constants/items: expected a JSON object');
    return _items = {
      for (final item in data.values.cast<Map<String, dynamic>>())
        if (item['id'] is int && item['dname'] is String)
          item['id'] as int: (name: item['dname'] as String, cost: (item['cost'] as num?)?.toInt() ?? 0),
    };
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
