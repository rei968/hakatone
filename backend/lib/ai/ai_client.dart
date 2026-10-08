class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => 'AiException: $message';
}

/// A text model that answers with a JSON object matching [schema].
/// The provider (Gemini now, Claude later) is swapped by passing another implementation.
abstract interface class AiClient {
  Future<Map<String, dynamic>> generateJson({
    required String system,
    required String prompt,
    required Map<String, Object?> schema,
  });
}
