import 'package:dio/dio.dart';

import '../domain/app_release.dart';

/// Звідки дізнатися про нову версію застосунку.
abstract interface class UpdateRepository {
  /// Останній реліз або `null`, якщо придатного немає. Кидає на помилках мережі.
  Future<AppRelease?> latestRelease();
}

/// GitHub Releases репозиторію команди (`UPDATE_REPO` у `config/app.json`).
/// API публічне, без токена: 60 запитів на годину з однієї IP, а ми питаємо раз на добу.
class GitHubUpdateRepository implements UpdateRepository {
  GitHubUpdateRepository({required this.repo, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/vnd.github+json'},
            ));

  /// `owner/name`, наприклад `rei968/hakatone`.
  final String repo;
  final Dio _dio;

  @override
  Future<AppRelease?> latestRelease() async {
    final response = await _dio.get<Map<String, dynamic>>('https://api.github.com/repos/$repo/releases/latest');
    final data = response.data;
    return data == null ? null : AppRelease.fromGitHub(data);
  }
}
