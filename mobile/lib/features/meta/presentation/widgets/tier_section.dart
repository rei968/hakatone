import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context.dart';
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

/// Колір вінрейту: від 52 % — танго, до 48 % — фласка.
Color winRateColor(BuildContext context, double winRate) {
  final colors = context.colors;
  if (winRate >= WinRate.good) return colors.success;
  if (winRate <= WinRate.bad) return colors.danger;
  return Theme.of(context).colorScheme.onSurface;
}

/// Зміна за тиждень: «+1,8» танго, «−0,9» фласка.
class DeltaText extends StatelessWidget {
  const DeltaText(this.delta, {super.key, this.style});

  final double delta;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = delta > 0.05 ? colors.success : delta < -0.05 ? colors.danger : colors.textMuted;
    return Text(Fmt.delta(delta), style: (style ?? context.text.labelSmall)?.copyWith(color: color));
  }
}

/// Рядок таблиці мети (як на Dotabuff): герой, тір і атрибут, вінрейт зі смужкою, пікрейт.
class MetaTableRow extends StatelessWidget {
  const MetaTableRow({super.key, required this.hero});

  final MetaHero hero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final attribute = hero.primaryAttribute;
    final label = context.text.labelSmall!;
    final barShare = ((hero.winRate - 40) / 20).clamp(0.04, 1.0);
    return Semantics(
      button: true,
      label: '${hero.name}, ${hero.tier.title}, вінрейт ${Fmt.percent(hero.winRate)}, пікрейт ${Fmt.percent(hero.pickRate)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(AppRoutes.hero(hero.id)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.space3, vertical: 10),
          child: Row(
            children: [
              HeroAvatar(name: hero.name, attribute: attribute, url: hero.avatarUrl, size: 40),
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
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: hero.tier.letter, style: label.copyWith(color: tierColor(colors, hero.tier))),
                        if (attribute != null) TextSpan(text: ' · ${attribute.label}'),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: m.space2),
              SizedBox(
                width: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.percent(hero.winRate),
                      style: label.copyWith(fontSize: 14, height: 18 / 14, color: winRateColor(context, hero.winRate)),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        width: 48,
                        height: 3,
                        child: Stack(
                          children: [
                            ColoredBox(color: colors.surface3, child: const SizedBox.expand()),
                            FractionallySizedBox(
                              widthFactor: barShare,
                              child: ColoredBox(color: winRateColor(context, hero.winRate), child: const SizedBox.expand()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  Fmt.percent(hero.pickRate),
                  textAlign: TextAlign.end,
                  style: label.copyWith(fontWeight: FontWeight.w500, fontVariations: wght(FontWeight.w500), color: colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
