import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dota/dota_assets.dart';
import '../theme/theme_context.dart';

/// Картинка з мережі, а поки вона вантажиться або коли не завантажилась —
/// [fallback] (BUG-02: жодних порожніх квадратів).
class NetworkPicture extends StatelessWidget {
  const NetworkPicture({super.key, required this.url, required this.fallback, this.fit = BoxFit.cover});

  final String? url;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = url;
    if (image == null) return fallback;
    return Image.network(
      image,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

/// Перші літери назви на нейтральній плашці.
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.color, this.fontSize = 11});

  final String name;
  final Color? color;
  final double fontSize;

  static String of(String name) {
    final words = name.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim().split(RegExp(r'\s+'));
    final letters = words.where((w) => w.isNotEmpty).map((w) => w[0]).take(3).join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      alignment: Alignment.center,
      color: colors.surface3,
      child: Text(
        of(name),
        maxLines: 1,
        style: context.text.labelSmall?.copyWith(fontSize: fontSize, height: 1, color: color ?? colors.textMuted),
      ),
    );
  }
}

/// Іконка предмета 88 × 64, як на CDN Steam.
class ItemIcon extends ConsumerWidget {
  const ItemIcon({super.key, required this.name, this.width = 44});

  final String name;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(dotaAssetsProvider).value?.itemIcon(name);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.metrics.radiusSm),
        child: SizedBox(
          width: width,
          height: width * 64 / 88,
          child: NetworkPicture(url: url, fallback: Initials(name, fontSize: width / 4)),
        ),
      ),
    );
  }
}

/// Квадратна іконка здібності. [url] з API має перевагу над довідником.
class AbilityIcon extends ConsumerWidget {
  const AbilityIcon({super.key, required this.name, this.heroId, this.url, this.size = 40});

  final String name;
  final int? heroId;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = url ?? ref.watch(dotaAssetsProvider).value?.abilityIcon(name, heroId: heroId);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: SizedBox.square(
          dimension: size,
          child: NetworkPicture(url: resolved, fallback: Initials(name, fontSize: size / 3.2)),
        ),
      ),
    );
  }
}
