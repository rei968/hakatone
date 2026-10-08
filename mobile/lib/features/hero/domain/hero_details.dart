import 'package:flutter/foundation.dart';

import '../../meta/domain/meta_report.dart';

/// Здібність з `HeroWithBuild.abilities`.
@immutable
class Ability {
  const Ability({
    required this.id,
    required this.name,
    required this.description,
    this.cooldown,
    this.manaCost,
    this.iconUrl,
    this.slotOrder,
  });

  factory Ability.fromJson(Map<String, dynamic> json) => Ability(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        cooldown: _nonEmpty(json['cooldown']),
        manaCost: _nonEmpty(json['mana_cost']),
        iconUrl: json['icon_url'] as String?,
        slotOrder: json['slot_order'] as int?,
      );

  final String id;
  final String name;
  final String description;

  /// «18/16/14/12» — як у грі, по рівнях. «0» — без кулдауну.
  final String? cooldown;
  final String? manaCost;
  final String? iconUrl;
  final int? slotOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'cooldown': cooldown,
        'mana_cost': manaCost,
        'icon_url': iconUrl,
        'slot_order': slotOrder,
      };
}

/// `HeroWithBuild.ai_build` — білд, який згенерував Gemini.
@immutable
class AiBuild {
  const AiBuild({required this.skillOrder, required this.coreItems, required this.tactics});

  factory AiBuild.fromJson(Map<String, dynamic> json) => AiBuild(
        skillOrder: [for (final s in json['skill_order'] as List? ?? const []) s as String],
        coreItems: [for (final s in json['core_items'] as List? ?? const []) s as String],
        tactics: (json['tactics'] as String? ?? '').trim(),
      );

  final List<String> skillOrder;
  final List<String> coreItems;
  final String tactics;

  bool get isEmpty => skillOrder.isEmpty && coreItems.isEmpty && tactics.isEmpty;

  Map<String, dynamic> toJson() => {'skill_order': skillOrder, 'core_items': coreItems, 'tactics': tactics};
}

/// Базові характеристики з сідів (`stats`). У `openapi.yaml` їх поки немає,
/// тому поле необов’язкове: немає — блок не показується.
@immutable
class HeroStats {
  const HeroStats({this.baseHp, this.baseMana, this.baseArmor, this.movementSpeed, this.damage});

  factory HeroStats.fromJson(Map<String, dynamic> json) => HeroStats(
        baseHp: (json['base_hp'] as num?)?.toInt(),
        baseMana: (json['base_mana'] as num?)?.toInt(),
        baseArmor: (json['base_armor'] as num?)?.toDouble(),
        movementSpeed: (json['movement_speed'] as num?)?.toInt(),
        damage: json['damage'] as String?,
      );

  final int? baseHp;
  final int? baseMana;
  final double? baseArmor;
  final int? movementSpeed;
  final String? damage;

  Map<String, dynamic> toJson() => {
        'base_hp': baseHp,
        'base_mana': baseMana,
        'base_armor': baseArmor,
        'movement_speed': movementSpeed,
        'damage': damage,
      };
}

/// Відповідь `GET /api/dota/heroes/{id}` (`HeroWithBuild` = `MetaHero` + здібності + AI-білд).
@immutable
class HeroDetails {
  const HeroDetails({
    required this.hero,
    required this.abilities,
    this.aiBuild,
    this.bio,
    this.attackType,
    this.stats,
  });

  factory HeroDetails.fromJson(Map<String, dynamic> json) {
    final abilities = [
      for (final a in json['abilities'] as List? ?? const []) Ability.fromJson(a as Map<String, dynamic>),
    ]..sort((a, b) => (a.slotOrder ?? 99).compareTo(b.slotOrder ?? 99));
    final build = json['ai_build'] == null ? null : AiBuild.fromJson(json['ai_build'] as Map<String, dynamic>);
    return HeroDetails(
      hero: MetaHero.fromJson(json),
      abilities: abilities,
      aiBuild: (build == null || build.isEmpty) ? null : build,
      bio: _nonEmpty(json['bio']),
      attackType: _nonEmpty(json['attack_type']),
      stats: json['stats'] == null ? null : HeroStats.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }

  final MetaHero hero;
  final List<Ability> abilities;
  final AiBuild? aiBuild;

  /// Лор героя.
  final String? bio;

  /// «Melee» або «Ranged».
  final String? attackType;
  final HeroStats? stats;

  Map<String, dynamic> toJson() => {
        ...hero.toJson(),
        'abilities': [for (final a in abilities) a.toJson()],
        'ai_build': aiBuild?.toJson(),
        'bio': bio,
        'attack_type': attackType,
        'stats': stats?.toJson(),
      };
}

/// 404 з `GET /api/dota/heroes/{id}`.
class HeroNotFoundException implements Exception {
  const HeroNotFoundException(this.heroId);

  final int heroId;

  @override
  String toString() => 'HeroNotFoundException($heroId)';
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
