import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_context.dart';
import '../../domain/hero_attribute.dart';

/// Колір атрибута: у грі він збігається з розхідниками.
Color attributeColor(AppColors colors, HeroAttribute? attribute) => switch (attribute) {
      HeroAttribute.strength => colors.attrStrength,
      HeroAttribute.agility => colors.attrAgility,
      HeroAttribute.intelligence => colors.attrIntelligence,
      HeroAttribute.universal => colors.attrUniversal,
      null => colors.textMuted,
    };

/// Аватар героя. Поки картинка вантажиться або коли вона не завантажилась,
/// на її місці монограма на кольорі атрибута (BUG-02 з DEMO_SCENARIO).
class HeroAvatar extends StatelessWidget {
  const HeroAvatar({super.key, required this.name, required this.attribute, this.url, this.size = 48});

  final String name;
  final HeroAttribute? attribute;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final monogram = _Monogram(name: name, color: attributeColor(context.colors, attribute), size: size);
    final image = url;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.metrics.radiusMd * size / 48),
        child: SizedBox.square(
          dimension: size,
          child: image == null
              ? monogram
              : Image.network(
                  image,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null ? child : monogram,
                  errorBuilder: (context, error, stack) => monogram,
                ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.color, required this.size});

  final String name;
  final Color color;
  final double size;

  String get _letters {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      alignment: Alignment.center,
      color: Color.alphaBlend(color.withValues(alpha: 0.24), colors.surface2),
      child: Text(
        _letters,
        style: context.text.titleSmall?.copyWith(
          fontSize: size * 0.29,
          color: Color.lerp(color, Colors.white, 0.38),
        ),
      ),
    );
  }
}
