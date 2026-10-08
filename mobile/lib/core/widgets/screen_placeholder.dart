import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Тимчасове тіло екрана, поки його не зроблено. Показує, що це за екран,
/// і кнопки переходів, щоб перевірити навігацію.
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({
    super.key,
    required this.title,
    required this.note,
    this.actions = const [],
  });

  final String title;
  final String note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return ListView(
      padding: EdgeInsets.fromLTRB(m.space4, m.space2, m.space4, m.space6),
      children: [
        Text(title, style: context.text.titleMedium),
        SizedBox(height: m.space1),
        Text(note, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
        if (actions.isNotEmpty) SizedBox(height: m.space6),
        for (final action in actions)
          Padding(padding: EdgeInsets.only(bottom: m.space3), child: action),
      ],
    );
  }
}
