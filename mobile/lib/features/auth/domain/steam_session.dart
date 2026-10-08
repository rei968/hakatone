import 'package:flutter/foundation.dart';

/// Гравець, який увійшов через Steam. Пароля й токенів застосунок не бачить:
/// лише Steam ID, підтверджений самим Steam.
@immutable
class SteamSession {
  const SteamSession({required this.steamId64, this.personaName, this.avatarUrl});

  factory SteamSession.fromJson(Map<String, dynamic> json) => SteamSession(
        steamId64: json['steam_id'] as String,
        personaName: json['persona_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  /// 17 цифр, `7656119…`. Рядком: на web число такої довжини втрачає точність.
  final String steamId64;
  final String? personaName;
  final String? avatarUrl;

  /// 32-бітний ID, яким гравця знає OpenDota.
  int get accountId => SteamIds.toAccountId(steamId64);

  SteamSession copyWith({String? personaName, String? avatarUrl}) => SteamSession(
        steamId64: steamId64,
        personaName: personaName ?? this.personaName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  Map<String, dynamic> toJson() => {'steam_id': steamId64, 'persona_name': personaName, 'avatar_url': avatarUrl};
}

abstract final class SteamIds {
  static final _base = BigInt.parse('76561197960265728');

  static int toAccountId(String steamId64) => (BigInt.parse(steamId64) - _base).toInt();

  static String fromAccountId(int accountId) => (_base + BigInt.from(accountId)).toString();

  /// Що гравець може вставити вручну: Steam ID (17 цифр), Friend ID / ID з OpenDota
  /// чи Dotabuff (до 10 цифр), посилання `steamcommunity.com/profiles/…`,
  /// `opendota.com/players/…` або `dotabuff.com/players/…`. Повертає Steam ID або `null`.
  static String? parse(String input) {
    final text = input.trim();
    final link = RegExp(r'(?:profiles|players)/(\d+)').firstMatch(text);
    final digits = link?.group(1) ?? (RegExp(r'^\d+$').hasMatch(text) ? text : null);
    if (digits == null) return null;
    if (digits.length == 17 && digits.startsWith('7656119')) return digits;
    if (digits.length <= 10) {
      final id = int.parse(digits);
      return id > 0 ? fromAccountId(id) : null;
    }
    return null;
  }
}
