import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Текст, який згенерував Claude: іскра кольору смоку й ледь фіолетовий текст.
/// Так гравець одразу відрізняє AI-підказку від статистики.
class AiText extends StatelessWidget {
  const AiText(this.text, {super.key, this.maxLines, this.style});

  final String text;
  final int? maxLines;

  /// За замовчуванням `bodyMedium`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = style ?? context.text.bodyMedium!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'Підказка AI: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: (base.fontSize ?? 13) * 0.2),
            child: Icon(Icons.auto_awesome, size: 12, color: colors.smoke),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: base.copyWith(color: Color.lerp(onSurface, colors.smoke, 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}
