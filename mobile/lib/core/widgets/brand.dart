import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Логотип MangoDota: манго з листком танго.
/// Контури перенесено з SVG у docs/design (сітка 24 × 24).
class MangoLogo extends StatelessWidget {
  const MangoLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: MangoPainter(fruit: colors.mango, leaf: colors.tango),
      ),
    );
  }
}

/// Малює манго в сітці 24 × 24. Ним же генеруються іконки (tool/generate_icons.dart).
class MangoPainter extends CustomPainter {
  const MangoPainter({required this.fruit, required this.leaf});

  final Color fruit;
  final Color leaf;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final body = Path()
      ..moveTo(15.6, 6.2)
      ..cubicTo(18.7, 7.7, 20.0, 11.3, 18.8, 14.8)
      ..cubicTo(17.4, 19.0, 13.2, 21.4, 9.4, 20.2)
      ..cubicTo(6.1, 19.2, 4.5, 15.9, 5.5, 12.4)
      ..cubicTo(6.7, 8.3, 11.2, 4.6, 15.6, 6.2)
      ..close();
    final leafPath = Path()
      ..moveTo(14.8, 5.9)
      ..cubicTo(15.2, 3.9, 16.8, 2.6, 19.1, 2.5)
      ..cubicTo(18.8, 4.6, 17.1, 6.1, 14.8, 5.9)
      ..close();
    final stem = Path()
      ..moveTo(14.4, 6.3)
      ..cubicTo(14.2, 5.4, 13.8, 4.7, 13.2, 4.2);
    canvas.drawPath(body, Paint()..color = fruit);
    canvas.drawPath(leafPath, Paint()..color = leaf);
    canvas.drawPath(
      stem,
      Paint()
        ..color = leaf
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(MangoPainter old) => old.fruit != fruit || old.leaf != leaf;
}

/// Плитка з логотипом, як у шапці: 40 dp, фон манго 14 %.
class MangoBadge extends StatelessWidget {
  const MangoBadge({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.mangoSoft,
        borderRadius: BorderRadius.circular(context.metrics.radiusLg),
      ),
      child: MangoLogo(size: size * 0.7),
    );
  }
}

/// Словесний знак: «Mango» кольором манго, «Dota» основним текстом.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.style});

  /// За замовчуванням `titleLarge`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.text.titleLarge;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Mango', style: TextStyle(color: context.colors.mango)),
          const TextSpan(text: 'Dota'),
        ],
      ),
      style: base,
      semanticsLabel: 'MangoDota',
    );
  }
}
