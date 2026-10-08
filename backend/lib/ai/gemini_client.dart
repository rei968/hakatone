import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:backend/ai/ai_client.dart';

/// Gemini API (Google AI Studio) via REST: POST models/{model}:generateContent.
class GeminiClient implements AiClient {
  GeminiClient({required this._apiKey, this.model = 'gemini-3.5-flash-lite', http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const _timeout = Duration(seconds: 30);

  final String _apiKey;
  final http.Client _http;
  final String model;

  @override
  Future<Map<String, dynamic>> generateJson({
    required String system,
    required String prompt,
    required Map<String, Object?> schema,
  }) async {
    final response = await _http
        .post(
          Uri.parse('$_baseUrl/$model:generateContent'),
          // The key goes in a header, never in the URL, so it can't leak into logs.
          headers: {'x-goog-api-key': _apiKey, 'content-type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'responseJsonSchema': schema,
              'temperature': 0.4,
            },
          }),
        )
        .timeout(_timeout);

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AiException('Gemini $model -> HTTP ${response.statusCode}: ${body['error']?['message']}');
    }

    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw AiException('Gemini $model returned no candidates: ${body['promptFeedback']}');
    }
    final parts = (candidates.first['content']?['parts'] as List?) ?? const [];
    final text = parts.where((p) => p['thought'] != true).map((p) => p['text'] ?? '').join();

    final result = jsonDecode(text);
    if (result is! Map<String, dynamic>) throw AiException('Gemini $model: expected a JSON object');
    return result;
  }
}
