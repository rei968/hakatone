import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ai_text.dart';
import '../../../core/widgets/app_skeleton.dart';
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
    final details = ref.watch(heroDetailsProvider(heroId));
    final m = context.metrics;
    return Scaffold(
      appBar: AppBar(),
      body: details.when(
        data: (d) => _HeroBody(details: d),
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
                onRetry: () => ref.invalidate(heroDetailsProvider(heroId)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.details});

  final HeroDetails details;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final hero = details.hero;
    final aiBuild = details.aiBuild;
    final stats = details.stats;
    final bio = details.bio;

    return ListView(
      padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space8),
      children: [
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
            Expanded(child: _Metric(label: 'Вінрейт', child: _WinRateValue(winRate: hero.winRate))),
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
        if (aiBuild != null) ...[
          SizedBox(height: m.space6),
          _AiBuildCard(aiBuild: aiBuild),
        ],
        if (details.abilities.isNotEmpty) ...[
          SizedBox(height: m.space6),
          const _SectionTitle('Здібності'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < details.abilities.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  _AbilityRow(ability: details.abilities[i]),
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
    context.text.labelSmall!.copyWith(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600);

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
  const _Chip({required this.text, this.leading});

  final String text;
  final Widget? leading;

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
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
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

/// AI-білд кольором смоку: порядок прокачки, ключові предмети, тактика.
class _AiBuildCard extends StatelessWidget {
  const _AiBuildCard({required this.aiBuild});

  final AiBuild aiBuild;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final label = context.text.labelMedium?.copyWith(color: colors.textMuted);

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
          if (aiBuild.skillOrder.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text('Порядок прокачки', style: label),
            SizedBox(height: m.space2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < aiBuild.skillOrder.length; i++)
                  Semantics(
                    label: 'Рівень ${i + 1}: ${aiBuild.skillOrder[i]}',
                    excludeSemantics: true,
                    child: _Chip(
                      text: aiBuild.skillOrder[i],
                      leading: Text(
                        '${i + 1}',
                        style: context.text.labelSmall?.copyWith(color: colors.smoke),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (aiBuild.coreItems.isNotEmpty) ...[
            SizedBox(height: m.space4),
            Text('Ключові предмети', style: label),
            SizedBox(height: m.space2),
            for (var i = 0; i < aiBuild.coreItems.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: m.space2),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.mangoSoft, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: context.text.labelSmall?.copyWith(color: colors.mango)),
                    ),
                    SizedBox(width: m.space3),
                    Expanded(
                      child: Text(
                        aiBuild.coreItems[i],
                        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (aiBuild.tactics.isNotEmpty) ...[
            SizedBox(height: m.space2),
            Text('Тактика', style: label),
            SizedBox(height: m.space2),
            AiText(aiBuild.tactics),
          ],
        ],
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.ability});

  final Ability ability;

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
          _AbilityIcon(ability: ability),
          SizedBox(width: m.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ability.name, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                if (costs.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(costs, style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w500, color: colors.textMuted)),
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

class _AbilityIcon extends StatelessWidget {
  const _AbilityIcon({required this.ability});

  final Ability ability;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fallback = Container(
      alignment: Alignment.center,
      color: colors.surface2,
      child: Text(
        '${ability.slotOrder ?? '•'}',
        style: context.text.labelSmall?.copyWith(color: colors.textMuted),
      ),
    );
    final url = ability.iconUrl;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.metrics.radiusMd),
        child: SizedBox.square(
          dimension: 40,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
                  errorBuilder: (context, error, stack) => fallback,
                ),
        ),
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
