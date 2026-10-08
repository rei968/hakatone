import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dota/rank.dart';
import '../../../core/format/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ai_text.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/dota_icons.dart';
import '../../../core/widgets/states.dart';
import '../../meta/presentation/widgets/hero_avatar.dart';
import '../../meta/presentation/widgets/tier_section.dart';
import '../application/hero_providers.dart';
import '../domain/hero_details.dart';

/// Картка героя з AI-білдом від Gemini (`GET /api/dota/heroes/{id}`).
class HeroScreen extends ConsumerWidget {
  const HeroScreen({super.key, required this.heroId});

  /// `id` героя (Steam / OpenDota), як у `docs/openapi.yaml`.
  final int heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(heroCardProvider(heroId));
    final m = context.metrics;
    return Scaffold(
      appBar: AppBar(actions: [const RankChip(), SizedBox(width: m.space4)]),
      body: card.when(
        // Потягнути вниз — запитати картку ще раз (наприклад, якщо AI-білд ще не був готовий).
        data: (c) => RefreshIndicator(
          onRefresh: () => ref.refresh(heroCardProvider(heroId).future),
          child: _HeroBody(details: c.details, cachedAt: c.fromCache ? c.savedAt : null, staleError: c.staleError),
        ),
        loading: () => const _HeroSkeleton(),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(m.space4),
          children: [
            if (error is HeroNotFoundException)
              _NotFound(heroId: heroId)
            else
              ErrorState(
                title: 'Не вдалося завантажити героя',
                message: loadErrorMessage(error),
                onRetry: () => ref.invalidate(heroCardProvider(heroId)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroBody extends ConsumerWidget {
  const _HeroBody({required this.details, this.cachedAt, this.staleError});

  final HeroDetails details;

  /// Не `null`, коли показуємо збережену картку, бо оновити не вдалося.
  final DateTime? cachedAt;
  final Object? staleError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(rankProvider);
    final m = context.metrics;
    final hero = details.hero;
    final aiBuild = details.aiBuild;
    final stats = details.stats;
    final bio = details.bio;
    final offline = staleError is ApiException && (staleError! as ApiException).failure == ApiFailure.network;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space8),
      children: [
        if (cachedAt != null) ...[
          StatusBanner(
            icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            iconColor: offline ? context.colors.clarity : context.colors.salve,
            message: offline
                ? 'Немає інтернету. Показуємо картку, збережену ${Fmt.dateTime(cachedAt!)}.'
                : 'Не вдалося оновити картку. Показуємо дані від ${Fmt.dateTime(cachedAt!)}.',
          ),
          SizedBox(height: m.space4),
        ],
        _Header(details: details),
        if (hero.roles.isNotEmpty) ...[
          SizedBox(height: m.space3),
          Wrap(
            spacing: m.space2 - 2,
            runSpacing: m.space2 - 2,
            children: [for (final role in hero.roles) _Chip(text: role)],
          ),
        ],
        SizedBox(height: m.space4),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: rank == Rank.all ? 'Вінрейт' : 'Вінрейт · ${rank.short}',
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _WinRateValue(winRate: hero.winRate),
                    if (hero.winRateDelta case final delta?)
                      Padding(padding: const EdgeInsets.only(bottom: 4), child: DeltaText(delta)),
                  ],
                ),
              ),
            ),
            SizedBox(width: m.space3),
            Expanded(
              child: _Metric(
                label: 'Пікрейт',
                child: Text(Fmt.percent(hero.pickRate), style: _bigNumber(context)),
              ),
            ),
          ],
        ),
        if (hero.aiSummary case final summary?) ...[
          SizedBox(height: m.space3),
          Container(
            padding: EdgeInsets.all(m.space3),
            decoration: BoxDecoration(
              color: context.colors.smokeSoft,
              borderRadius: BorderRadius.circular(m.radiusLg),
            ),
            child: AiText(summary),
          ),
        ],
        SizedBox(height: m.space6),
        if (aiBuild != null)
          _AiBuildCard(aiBuild: aiBuild, heroId: hero.id)
        else
          // `ai_build: null` — AI не встиг або впав. Це не помилка: потягніть вниз пізніше.
          StatusBanner(
            icon: Icons.auto_awesome,
            iconColor: context.colors.smoke,
            message: 'AI-білд для цього героя поки недоступний. Потягніть екран вниз, щоб спробувати ще раз.',
          ),
        if (details.abilities.isNotEmpty) ...[
          SizedBox(height: m.space6),
          const _SectionTitle('Здібності'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < details.abilities.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  _AbilityRow(ability: details.abilities[i], heroId: hero.id),
                ],
              ],
            ),
          ),
        ],
        if (stats != null) ...[
          SizedBox(height: m.space6),
          const _SectionTitle('Характеристики'),
          _StatsCard(stats: stats),
        ],
        if (bio != null) ...[
          SizedBox(height: m.space6),
          const _SectionTitle('Історія'),
          _ExpandableText(bio),
        ],
      ],
    );
  }
}

TextStyle _bigNumber(BuildContext context) =>
    context.text.labelSmall!.copyWith(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600));

class _Header extends StatelessWidget {
  const _Header({required this.details});

  final HeroDetails details;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final hero = details.hero;
    final attribute = hero.primaryAttribute;
    final attack = switch (details.attackType) {
      'Melee' => 'Ближній бій',
      'Ranged' => 'Дальній бій',
      _ => null,
    };
    final subtitle = [if (attribute != null) attribute.label, if (attack != null) attack].join(' · ');

    return Row(
      children: [
        HeroAvatar(name: hero.name, attribute: attribute, url: hero.avatarUrl, size: 72),
        SizedBox(width: m.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hero.name, style: context.text.headlineSmall),
              SizedBox(height: m.space1),
              Row(
                children: [
                  TierBadge(tier: hero.tier, size: 22),
                  SizedBox(width: m.space2),
                  Expanded(
                    child: Text(
                      '${hero.tier.title} · ${hero.tier.description}',
                      style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: attributeColor(colors, attribute), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(subtitle, style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: m.space2, vertical: m.space1),
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(m.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(m.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.bodySmall?.copyWith(color: context.colors.textMuted)),
            const SizedBox(height: 2),
            child,
          ],
        ),
      ),
    );
  }
}

class _WinRateValue extends StatelessWidget {
  const _WinRateValue({required this.winRate});

  final double winRate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = winRate >= WinRate.good
        ? colors.success
        : winRate <= WinRate.bad
            ? colors.danger
            : Theme.of(context).colorScheme.onSurface;
    return Text(Fmt.percent(winRate), style: _bigNumber(context).copyWith(color: color));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.metrics.space3),
      child: Semantics(header: true, child: Text(text, style: context.text.titleMedium)),
    );
  }
}

/// AI-білд кольором смоку (ескізи v2): скілбілд іконками на 1–18 рівнях з талантами L/R,
/// дерево талантів, ключові предмети зі стрілками й таймінгами, ситуативні предмети, тактика.
class _AiBuildCard extends StatelessWidget {
  const _AiBuildCard({required this.aiBuild, required this.heroId});

  final AiBuild aiBuild;
  final int heroId;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final label = context.text.labelMedium?.copyWith(color: colors.textMuted);
    final steps = aiBuild.steps;
    final hasTimings = aiBuild.coreItems.any((item) => aiBuild.timingOf(item) != null);
    final abilities = <String>{for (final s in steps) if (s.ability case final a?) a}.toList();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(m.radiusXl),
        border: Border.all(color: colors.smoke.withValues(alpha: 0.35)),
      ),
      padding: EdgeInsets.all(m.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colors.smoke),
                SizedBox(width: m.space2),
                Expanded(child: Text('AI-білд від Gemini', style: context.text.titleMedium)),
              ],
            ),
          ),
          if (steps.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text('Скілбілд · 1–${steps.length} рівень', style: label),
            SizedBox(height: m.space2),
            for (var row = 0; row * 9 < steps.length; row++) ...[
              if (row > 0) SizedBox(height: m.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < 9; col++) ...[
                    if (col > 0) const SizedBox(width: 4),
                    Expanded(
                      child: row * 9 + col < steps.length
                          ? _SkillCell(step: steps[row * 9 + col], level: row * 9 + col + 1, heroId: heroId)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
            if (abilities.isNotEmpty) ...[
              SizedBox(height: m.space2),
              Text(abilities.join(' · '), style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
            ],
          ],
          if (aiBuild.talents.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text('Таланти', style: label),
            SizedBox(height: m.space2),
            for (final talent in aiBuild.talents)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  label: 'Рівень ${talent.level}: ${talent.side == 'L' ? 'лівий' : 'правий'} талант, ${talent.name}',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${talent.level}', style: context.text.labelSmall?.copyWith(color: colors.textMuted)),
                      ),
                      _SidePill(side: 'L', selected: talent.side == 'L'),
                      const SizedBox(width: 4),
                      _SidePill(side: 'R', selected: talent.side == 'R'),
                      SizedBox(width: m.space2),
                      Expanded(child: Text(talent.name, style: context.text.bodySmall)),
                    ],
                  ),
                ),
              ),
          ],
          if (aiBuild.coreItems.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text(hasTimings ? 'Ключові предмети · середній таймінг' : 'Ключові предмети', style: label),
            SizedBox(height: m.space2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < aiBuild.coreItems.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(Icons.chevron_right_rounded, size: 18, color: colors.textSubtle),
                      ),
                    _CoreItem(name: aiBuild.coreItems[i], timing: aiBuild.timingOf(aiBuild.coreItems[i])),
                  ],
                ],
              ),
            ),
          ],
          if (aiBuild.situationalItems.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text('Ситуативні предмети', style: label),
            SizedBox(height: m.space2),
            LayoutBuilder(
              builder: (context, constraints) {
                final half = (constraints.maxWidth - m.space2) / 2;
                return Wrap(
                  spacing: m.space2,
                  runSpacing: m.space3,
                  children: [
                    for (final item in aiBuild.situationalItems)
                      SizedBox(
                        width: constraints.maxWidth < 300 ? constraints.maxWidth : half,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ItemIcon(name: item.name, width: 36),
                            SizedBox(width: m.space2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600)),
                                  ),
                                  if (item.reason.isNotEmpty)
                                    Text(
                                      item.reason,
                                      style: context.text.bodySmall?.copyWith(color: Color.lerp(colors.textMuted, colors.smoke, 0.45)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          if (aiBuild.tactics.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text('Тактика', style: label),
            SizedBox(height: m.space2),
            AiText(aiBuild.tactics),
          ],
        ],
      ),
    );
  }
}

/// Клітинка скілбілда: іконка здібності, L/R для таланту або «—», під нею номер рівня.
class _SkillCell extends StatelessWidget {
  const _SkillCell({required this.step, required this.level, required this.heroId});

  final SkillStep step;
  final int level;
  final int heroId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final description = switch (step.kind) {
      SkillStepKind.ability => step.ability!,
      SkillStepKind.talentLeft => 'лівий талант',
      SkillStepKind.talentRight => 'правий талант',
      SkillStepKind.none => 'без очка прокачки',
    };
    return Tooltip(
      message: 'Рівень $level: $description',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: 'Рівень $level: $description',
        excludeSemantics: true,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) => switch (step.kind) {
                  SkillStepKind.ability => AbilityIcon(name: step.ability!, heroId: heroId, size: constraints.maxWidth),
                  SkillStepKind.none => _Square(color: colors.surface2, text: '—', textColor: colors.textSubtle),
                  _ => _Square(
                      color: colors.clarity,
                      text: step.kind == SkillStepKind.talentLeft ? 'L' : 'R',
                      textColor: colors.ink,
                    ),
                },
              ),
            ),
            const SizedBox(height: 2),
            Text('$level', style: context.text.labelSmall?.copyWith(fontSize: 10, height: 1.2, color: colors.textSubtle)),
          ],
        ),
      ),
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.color, required this.text, required this.textColor});

  final Color color;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: context.text.labelSmall?.copyWith(fontSize: 12, color: textColor)),
    );
  }
}

class _SidePill extends StatelessWidget {
  const _SidePill({required this.side, required this.selected});

  final String side;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 22,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.clarity : colors.surface2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(side, style: context.text.labelSmall?.copyWith(height: 1, color: selected ? colors.ink : colors.textSubtle)),
    );
  }
}

class _CoreItem extends StatelessWidget {
  const _CoreItem({required this.name, this.timing});

  final String name;
  final Duration? timing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = timing;
    return Semantics(
      label: time == null ? name : '$name, близько ${Fmt.clock(time)}',
      excludeSemantics: true,
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            ItemIcon(name: name, width: 46),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(fontSize: 11, height: 14 / 11),
            ),
            if (time != null) Text(Fmt.clock(time), style: context.text.labelSmall?.copyWith(color: colors.mango)),
          ],
        ),
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.ability, required this.heroId});

  final Ability ability;
  final int heroId;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final costs = [
      if (ability.cooldown case final cd? when cd != '0') 'КД $cd с',
      if (ability.manaCost case final mana? when mana != '0') 'Мана $mana',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.all(m.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AbilityIcon(name: ability.name, url: ability.iconUrl, heroId: heroId),
          SizedBox(width: m.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ability.name, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600))),
                if (costs.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(costs, style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w500, fontVariations: wght(FontWeight.w500), color: colors.textMuted)),
                ],
                if (ability.description.isNotEmpty) ...[
                  SizedBox(height: m.space1),
                  Text(ability.description, style: context.text.bodyMedium?.copyWith(color: colors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final HeroStats stats;

  @override
  Widget build(BuildContext context) {
    String armor(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    final rows = <(String, String)>[
      if (stats.baseHp case final hp?) ('Здоров’я', '$hp'),
      if (stats.baseMana case final mana?) ('Мана', '$mana'),
      if (stats.baseArmor case final a?) ('Броня', armor(a)),
      if (stats.movementSpeed case final speed?) ('Швидкість руху', '$speed'),
      if (stats.damage case final dmg?) ('Шкода', dmg.replaceAll('-', '–')),
    ];
    final m = context.metrics;
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: m.space3, vertical: m.space1),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: EdgeInsets.symmetric(vertical: m.space2 + 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(rows[i].$1, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
                    ),
                    Text(rows[i].$2, style: context.text.labelSmall?.copyWith(fontSize: 14, height: 20 / 14)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(color: context.colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 4,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                child: Text(_expanded ? 'Згорнути' : 'Читати далі'),
              ),
          ],
        );
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.heroId});

  final int heroId;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(m.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Такого героя немає', style: context.text.titleMedium),
            SizedBox(height: m.space1),
            Text(
              'Героя з номером $heroId немає в базі. Можливо, посилання застаріло.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted),
            ),
            SizedBox(height: m.space4),
            FilledButton(onPressed: () => context.go(AppRoutes.meta), child: const Text('До мети героїв')),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Semantics(
      label: 'Завантаження картки героя',
      child: ListView(
        padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space8),
        children: [
          const SlowHint(
            after: Duration(seconds: 2),
            text: 'Gemini складає білд для цього героя. Перший раз це до 10 секунд, далі миттєво.',
          ),
          SizedBox(height: m.space3),
          Row(
            children: [
              AppSkeleton(width: 72, height: 72, radius: m.radiusMd * 1.5),
              SizedBox(width: m.space4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(widthFactor: 0.6, child: AppSkeleton(height: 22)),
                    SizedBox(height: 10),
                    FractionallySizedBox(widthFactor: 0.8, child: AppSkeleton(height: 12)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: m.space6),
          const Row(
            children: [
              Expanded(child: AppSkeleton(height: 72, radius: 16)),
              SizedBox(width: 12),
              Expanded(child: AppSkeleton(height: 72, radius: 16)),
            ],
          ),
          SizedBox(height: m.space6),
          const AppSkeleton(height: 220, radius: 16),
          SizedBox(height: m.space6),
          const AppSkeleton(height: 160, radius: 16),
        ],
      ),
    );
  }
}
