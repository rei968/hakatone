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

  /// GET /heroStats: one entry per hero with pub_pick/pub_win, roles, base stats, img.
  Future<List<Map<String, dynamic>>> heroStats() async {
    final data = await _get('/heroStats');
    if (data is! List) throw OpenDotaException('/heroStats: expected a JSON array');
    return data.cast<Map<String, dynamic>>();
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
