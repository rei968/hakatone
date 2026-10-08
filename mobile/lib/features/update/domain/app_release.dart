import 'package:flutter/foundation.dart';

/// Реліз застосунку на GitHub: версія з тегу (`v0.2.0` → `0.2.0`) і APK серед assets.
@immutable
class AppRelease {
  const AppRelease({required this.version, required this.apkUrl, this.sha256, this.notes});

  /// Розбирає `GET /repos/{owner}/{repo}/releases/latest`. `null`, якщо реліз не годиться
  /// для оновлення: чернетка, пре-реліз, тег не схожий на версію або немає APK.
  static AppRelease? fromGitHub(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final version = parseVersion(json['tag_name'] as String? ?? '');
    if (version == null) return null;

    final apk = [
      for (final asset in json['assets'] as List? ?? const [])
        if (asset is Map && '${asset['name']}'.toLowerCase().endsWith('.apk')) asset,
    ].firstOrNull;
    final url = apk?['browser_download_url'];
    if (url is! String || !url.startsWith('https://')) return null;

    // GitHub віддає контрольну суму файлу як "sha256:<hex>"; нею перевіряємо завантажений APK.
    final digest = apk?['digest'];
    final sha256 = digest is String && digest.startsWith('sha256:') ? digest.substring(7) : null;
    final notes = (json['body'] as String?)?.trim();

    return AppRelease(
      version: version.join('.'),
      apkUrl: url,
      sha256: sha256,
      notes: (notes == null || notes.isEmpty) ? null : notes,
    );
  }

  /// `0.2.0`
  final String version;
  final String apkUrl;

  /// SHA-256 APK у hex, якщо GitHub його віддав.
  final String? sha256;

  /// Опис релізу з GitHub.
  final String? notes;
}

/// `v1.2.3`, `1.2.3`, `1.2.3+4`, `1.2.3-beta` → `[1, 2, 3]`; інше — `null`.
List<int>? parseVersion(String value) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(value.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// `true`, якщо [candidate] новіша за [current]. Нерозпізнані версії ніколи не новіші.
bool isNewerVersion(String candidate, String current) {
  final a = parseVersion(candidate), b = parseVersion(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}
