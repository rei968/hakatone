import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/ai_text.dart';
import '../../domain/meta_report.dart';
import '../../domain/tier.dart';
import 'hero_avatar.dart';

Color tierColor(AppColors colors, Tier tier) => switch (tier) {
      Tier.s => colors.tierS,
      Tier.a => colors.tierA,
      Tier.b => colors.tierB,
      Tier.c => colors.tierC,
      Tier.none => colors.surface3,
    };

/// Бейдж тіру 32 × 32: заливка розхідника, літера кольору ink.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.size = 32});

  final Tier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tierColor(colors, tier),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        tier.letter,
        style: context.text.titleSmall?.copyWith(
          fontWeight: FontWeight.w700, fontVariations: wght(FontWeight.w700),
          color: tier == Tier.none ? Theme.of(context).colorScheme.onSurface : colors.ink,
        ),
      ),
    );
  }
}

/// Вінрейт великим моноширинним шрифтом і пікрейт під ним.
/// Колір лише для явних сигналів: від 52 % — танго, до 48 % — фласка.
class WinRate extends StatelessWidget {
  const WinRate({super.key, required this.winRate, required this.pickRate, this.showPickRate = true});

  static const good = 52.0;
  static const bad = 48.0;

  final double winRate;
  final double pickRate;
  final bool showPickRate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.text.labelSmall!;
    final color = winRate >= good
        ? colors.success
        : winRate <= bad
            ? colors.danger
            : Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(Fmt.percent(winRate), style: label.copyWith(fontSize: 15, height: 20 / 15, color: color)),
        if (showPickRate)
          Text(
            'пік ${Fmt.percent(pickRate)}',
            style: label.copyWith(fontWeight: FontWeight.w500, fontVariations: wght(FontWeight.w500), height: 14 / 11, color: colors.textMuted),
          ),
      ],
    );
  }
}

/// Заголовок секції тіру: бейдж, назва, опис і кількість героїв.
class TierHeader extends StatelessWidget {
  const TierHeader({super.key, required this.tier, required this.count});

  final Tier tier;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '${tier.title}, ${tier.description.toLowerCase()}, ${Fmt.heroes(count)}',
      excludeSemantics: true,
      child: Row(
        children: [
          TierBadge(tier: tier),
          SizedBox(width: context.metrics.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.title, style: context.text.titleMedium),
                Text(
                  '${tier.description} · ${Fmt.heroes(count)}',
                  style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Рядок героя: аватар, ім’я, атрибут і ролі, вінрейт; під ними на всю
/// ширину AI-підказка, щоб не тиснулась між ім’ям і вінрейтом.
class MetaHeroRow extends StatelessWidget {
  const MetaHeroRow({super.key, required this.hero, this.flash = false});

  final MetaHero hero;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final attribute = hero.primaryAttribute;
    final roles = hero.roles.take(2).join(', ');
    final subtitle = [if (attribute != null) attribute.label, if (roles.isNotEmpty) roles].join(' · ');
    final narrow = MediaQuery.sizeOf(context).width < 340;

    final row = InkWell(
      onTap: () => context.push(AppRoutes.hero(hero.id)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(m.space3, 14, m.space3, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroAvatar(name: hero.name, attribute: attribute, url: hero.avatarUrl),
                SizedBox(width: m.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: attributeColor(colors, attribute),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: m.space3),
                WinRate(winRate: hero.winRate, pickRate: hero.pickRate, showPickRate: !narrow),
              ],
            ),
            if (hero.aiSummary case final summary?)
              Padding(
                padding: EdgeInsets.only(left: m.thumb + m.space3, top: m.space2),
                child: AiText(summary, maxLines: narrow ? 1 : 2),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: [
        hero.name,
        if (attribute != null) attribute.label.toLowerCase(),
        'вінрейт ${Fmt.percent(hero.winRate)}',
        'пікрейт ${Fmt.percent(hero.pickRate)}',
        if (hero.aiSummary != null) 'Підказка AI: ${hero.aiSummary}',
      ].join(', '),
      excludeSemantics: true,
      child: flash ? _Flash(child: row) : row,
    );
  }
}

/// Один спалах дасту 12 % → 0 за 1200 ms (стан «Щойно оновлено»).
class _Flash extends StatelessWidget {
  const _Flash({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final dust = context.colors.dust;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.12, end: 0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, alpha, child) => ColoredBox(color: dust.withValues(alpha: alpha), child: child),
      child: child,
    );
  }
}
