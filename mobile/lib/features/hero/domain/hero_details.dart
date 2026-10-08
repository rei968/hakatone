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

/// Талант з `ai_build.talents`: рівень 10/15/20/25 і бік дерева, як у грі.
@immutable
class Talent {
  const Talent({required this.level, required this.side, required this.name});

  static Talent? fromJson(Object? json) {
    if (json is! Map) return null;
    final level = (json['level'] as num?)?.toInt();
    final side = (json['side'] as String?)?.trim().toUpperCase();
    final name = (json['name'] as String?)?.trim();
    if (level == null || (side != 'L' && side != 'R') || name == null || name.isEmpty) return null;
    return Talent(level: level, side: side!, name: name);
  }

  final int level;

  /// `L` або `R`.
  final String side;
  final String name;

  Map<String, dynamic> toJson() => {'level': level, 'side': side, 'name': name};
}

/// Ситуативний предмет від AI і коротко, проти чого він.
@immutable
class SituationalItem {
  const SituationalItem({required this.name, required this.reason});

  static SituationalItem? fromJson(Object? json) {
    final name = json is Map ? (json['name'] as String?)?.trim() : (json is String ? json.trim() : null);
    if (name == null || name.isEmpty) return null;
    return SituationalItem(name: name, reason: json is Map ? (json['reason'] as String? ?? '').trim() : '');
  }

  final String name;
  final String reason;

  Map<String, dynamic> toJson() => {'name': name, 'reason': reason};
}

enum SkillStepKind { ability, talentLeft, talentRight, none }

/// Що качається на одному рівні.
@immutable
class SkillStep {
  const SkillStep(this.kind, [this.ability]);

  factory SkillStep.parse(String raw) => switch (raw.trim().toUpperCase()) {
        'L' => const SkillStep(SkillStepKind.talentLeft),
        'R' => const SkillStep(SkillStepKind.talentRight),
        '' || '-' || '—' => const SkillStep(SkillStepKind.none),
        _ => SkillStep(SkillStepKind.ability, raw.trim()),
      };

  final SkillStepKind kind;

  /// Назва здібності для [SkillStepKind.ability].
  final String? ability;

  bool get isTalent => kind == SkillStepKind.talentLeft || kind == SkillStepKind.talentRight;
}

/// `HeroWithBuild.ai_build` — білд, який згенерував Gemini. Нові поля (таланти,
/// таймінги, ситуативні предмети) необов’язкові: старі білди їх не мають.
@immutable
class AiBuild {
  const AiBuild({
    required this.skillOrder,
    required this.coreItems,
    required this.tactics,
    this.talents = const [],
    this.itemTimings = const {},
    this.situationalItems = const [],
  });

  factory AiBuild.fromJson(Map<String, dynamic> json) {
    String? name(Object? value) => switch (value) {
          final String s => s,
          final Map m => (m['name'] ?? m['ability']) as String?,
          _ => null,
        };
    final timings = <String, int>{
      for (final MapEntry(:key, :value) in (json['item_timings'] as Map? ?? const {}).entries)
        if (value is num) '$key': value.toInt(),
    };
    // Запасний формат: core_items об’єктами з таймінгом усередині.
    for (final item in json['core_items'] as List? ?? const []) {
      if (item is Map && item['name'] is String && item['timing_sec'] is num) {
        timings.putIfAbsent(item['name'] as String, () => (item['timing_sec'] as num).toInt());
      }
    }
    return AiBuild(
      skillOrder: [for (final s in json['skill_order'] as List? ?? const []) name(s) ?? '-'],
      coreItems: [for (final s in json['core_items'] as List? ?? const []) if (name(s) case final n?) n],
      tactics: (json['tactics'] as String? ?? '').trim(),
      talents: [for (final t in json['talents'] as List? ?? const []) if (Talent.fromJson(t) case final talent?) talent]
        ..sort((a, b) => b.level.compareTo(a.level)),
      itemTimings: timings,
      situationalItems: [
        for (final s in json['situational_items'] as List? ?? const [])
          if (SituationalItem.fromJson(s) case final item?) item,
      ],
    );
  }

  final List<String> skillOrder;
  final List<String> coreItems;
  final String tactics;

  /// Від 25-го рівня до 10-го, як дерево талантів у грі.
  final List<Talent> talents;

  /// Назва предмета → середній таймінг покупки в секундах (усі ранги).
  final Map<String, int> itemTimings;
  final List<SituationalItem> situationalItems;

  List<SkillStep> get steps => [for (final s in skillOrder) SkillStep.parse(s)];

  Duration? timingOf(String item) {
    final seconds = itemTimings[item] ??
        itemTimings.entries.where((e) => e.key.toLowerCase() == item.toLowerCase()).firstOrNull?.value;
    return seconds == null ? null : Duration(seconds: seconds);
  }

  bool get isEmpty => skillOrder.isEmpty && coreItems.isEmpty && tactics.isEmpty;

  Map<String, dynamic> toJson() => {
        'skill_order': skillOrder,
        'core_items': coreItems,
        'tactics': tactics,
        'talents': [for (final t in talents) t.toJson()],
        'item_timings': itemTimings,
        'situational_items': [for (final s in situationalItems) s.toJson()],
      };
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
