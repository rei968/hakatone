import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dota/dota_assets.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/dota_icons.dart';
import '../domain/player.dart';

/// Щільно складає кола навколо центру: кожне наступне торкається вже покладених
/// і стоїть якомога ближче до центру. Ширина важить менше за висоту, тож купка
/// виходить ширшою, ніж вищою — під екран телефона. Повертає центри кіл.
List<Offset> packCircles(List<double> radii, {double gap = 0.06}) {
  final placed = <(Offset, double)>[];
  for (final r in radii) {
    if (placed.isEmpty) {
      placed.add((Offset.zero, r));
      continue;
    }
    Offset? best;
    var bestScore = double.infinity;
    for (final (center, radius) in placed) {
      for (var step = 0; step < 36; step++) {
        final angle = step * math.pi / 18;
        final candidate = center + Offset(math.cos(angle), math.sin(angle)) * (radius + r + gap);
        final fits = placed.every((p) => (p.$1 - candidate).distance >= p.$2 + r + gap - 1e-6);
        if (!fits) continue;
        final score = math.pow(candidate.dx * 0.6, 2) + math.pow(candidate.dy, 2);
        if (score < bestScore) {
          bestScore = score.toDouble();
          best = candidate;
        }
      }
    }
    placed.add((best!, r));
  }
  return [for (final (center, _) in placed) center];
}

/// «Пул героїв»: бульбашки-портрети, розмір — кількість ігор, обідок — вінрейт
/// (≥ 55 % танго, 45–55 % даст, ≤ 45 % фласка). Решта героїв — одна бульбашка «+N».
class HeroPoolChart extends ConsumerWidget {
  const HeroPoolChart({super.key, required this.pool, this.maxBubbles = 8, this.height = 210});

  final List<HeroUsage> pool;
  final int maxBubbles;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(dotaAssetsProvider).value;
    final shown = pool.take(maxBubbles).toList();
    final rest = pool.skip(maxBubbles).toList();
    final restGames = rest.fold<int>(0, (sum, h) => sum + h.games);
    final maxGames = shown.isEmpty ? 1 : shown.first.games;
    double radius(int games) => math.max(0.34, math.sqrt(games / maxGames));
    final radii = [for (final h in shown) radius(h.games), if (rest.isNotEmpty) math.max(0.3, radius(restGames) * 0.7)];
    final centers = packCircles(radii);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (radii.isEmpty) return const SizedBox.shrink();
        var left = double.infinity, top = double.infinity, right = -double.infinity, bottom = -double.infinity;
        for (var i = 0; i < radii.length; i++) {
          left = math.min(left, centers[i].dx - radii[i]);
          right = math.max(right, centers[i].dx + radii[i]);
          top = math.min(top, centers[i].dy - radii[i]);
          bottom = math.max(bottom, centers[i].dy + radii[i]);
        }
        final scale = math.min(constraints.maxWidth / (right - left), height / (bottom - top));
        final offsetX = (constraints.maxWidth - (right - left) * scale) / 2;
        final offsetY = (height - (bottom - top) * scale) / 2;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (var i = 0; i < radii.length; i++)
                Positioned(
                  left: offsetX + (centers[i].dx - radii[i] - left) * scale,
                  top: offsetY + (centers[i].dy - radii[i] - top) * scale,
                  width: radii[i] * 2 * scale,
                  height: radii[i] * 2 * scale,
                  child: i < shown.length
                      ? _Bubble(usage: shown[i], hero: assets?.hero(shown[i].heroId))
                      : _RestBubble(heroes: rest.length, games: restGames),
                ),
            ],
          ),
        );
      },
    );
  }
}

Color winRateRing(BuildContext context, double winRate) {
  final colors = context.colors;
  if (winRate >= 55) return colors.tango;
  if (winRate <= 45) return colors.salve;
  return colors.dust;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.usage, required this.hero});

  final HeroUsage usage;
  final DotaHeroInfo? hero;

  @override
  Widget build(BuildContext context) {
    final name = hero?.name ?? 'Герой ${usage.heroId}';
    final summary = '$name · ${Fmt.games(usage.games)} · ${usage.winRate.round()}%';
    return Tooltip(
      message: summary,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: summary,
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            return Container(
              padding: EdgeInsets.all(size > 60 ? 3 : 2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: winRateRing(context, usage.winRate)),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkPicture(url: hero?.imageUrl, fallback: Initials(name, fontSize: size / 4.5)),
                    if (size >= 64)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(top: 2, bottom: size * 0.09),
                          color: Colors.black.withValues(alpha: 0.55),
                          child: Text(
                            '${usage.games} · ${usage.winRate.round()}%',
                            textAlign: TextAlign.center,
                            style: context.text.labelSmall?.copyWith(fontSize: 11, height: 1.2, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RestBubble extends StatelessWidget {
  const _RestBubble({required this.heroes, required this.games});

  final int heroes;
  final int games;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: 'Ще ${Fmt.heroes(heroes)}, ${Fmt.games(games)}',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface2,
          border: Border.all(color: colors.textSubtle),
        ),
        child: Text('+$heroes', style: context.text.labelSmall?.copyWith(color: colors.textMuted)),
      ),
    );
  }
}
