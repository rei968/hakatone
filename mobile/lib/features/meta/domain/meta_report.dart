import 'package:flutter/foundation.dart';

import 'hero_attribute.dart';
import 'tier.dart';

/// `MetaHero` з `docs/openapi.yaml`.
@immutable
class MetaHero {
  const MetaHero({
    required this.id,
    required this.name,
    required this.winRate,
    required this.pickRate,
    required this.primaryAttribute,
    required this.roles,
    required this.avatarUrl,
    required this.tier,
    required this.aiSummary,
    this.matches,
    this.winRateDelta,
  });

  factory MetaHero.fromJson(Map<String, dynamic> json) => MetaHero(
        id: json['id'] as int,
        name: json['name'] as String,
        winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
        pickRate: (json['pick_rate'] as num?)?.toDouble() ?? 0,
        primaryAttribute: HeroAttribute.fromApi(json['primary_attr'] as String?),
        roles: [for (final role in json['roles'] as List? ?? const []) role as String],
        avatarUrl: json['avatar_url'] as String?,
        tier: Tier.fromApi(json['tier'] as String?),
        aiSummary: _nonEmpty(json['ai_summary'] as String?),
        matches: (json['matches'] as num?)?.toInt(),
        winRateDelta: (json['win_rate_delta'] as num?)?.toDouble(),
      );

  final int id;
  final String name;

  /// У відсотках: 53.4 означає 53,4 %.
  final double winRate;
  final double pickRate;
  final HeroAttribute? primaryAttribute;
  final List<String> roles;
  final String? avatarUrl;
  final Tier tier;

  /// Коротка підказка від AI (Gemini). Немає — рядок рендериться без неї.
  final String? aiSummary;

  /// Скільки разів героя взяли в обраному ранзі.
  final int? matches;

  /// Зміна вінрейту за тиждень, процентні пункти (завжди за всі ранги).
  final double? winRateDelta;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'win_rate': winRate,
        'pick_rate': pickRate,
        'primary_attr': primaryAttribute?.apiValue,
        'roles': roles,
        'avatar_url': avatarUrl,
        'tier': tier == Tier.none ? null : tier.letter,
        'ai_summary': aiSummary,
        'matches': matches,
        'win_rate_delta': winRateDelta,
      };
}

/// Відповідь `GET /api/meta/dota`.
@immutable
class MetaReport {
  const MetaReport({required this.updatedAt, required this.patch, required this.heroes, this.rank, this.totalMatches});

  factory MetaReport.fromJson(Map<String, dynamic> json) => MetaReport(
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
        patch: json['patch'] as String? ?? '',
        rank: json['rank'] as String?,
        totalMatches: (json['total_matches'] as num?)?.toInt(),
        heroes: [
          for (final hero in json['meta_heroes'] as List? ?? const [])
            MetaHero.fromJson(hero as Map<String, dynamic>),
        ],
      );

  /// Коли бекенд востаннє перерахував мету (UTC). Бекенд віддає `null`,
  /// коли в його БД ще немає героїв — тоді індикатор показує лише патч.
  final DateTime? updatedAt;
  final String patch;
  final List<MetaHero> heroes;

  /// Для якого рангу пораховано (`all`, `divine`…). Старий бекенд поля не має.
  final String? rank;

  /// Матчів у вибірці рангу.
  final int? totalMatches;

  Map<String, dynamic> toJson() => {
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'patch': patch,
        'rank': rank,
        'total_matches': totalMatches,
        'meta_heroes': [for (final hero in heroes) hero.toJson()],
      };

  /// Тіри від S до C, «Без тіру» наприкінці; усередині — за вінрейтом.
  /// Порожні тіри не повертаються.
  List<(Tier, List<MetaHero>)> get byTier {
    final groups = <(Tier, List<MetaHero>)>[];
    for (final tier in Tier.values) {
      final list = heroes.where((h) => h.tier == tier).toList()
        ..sort((a, b) => b.winRate.compareTo(a.winRate));
      if (list.isNotEmpty) groups.add((tier, list));
    }
    return groups;
  }
}

String? _nonEmpty(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();
