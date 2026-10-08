import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Банер над контентом: офлайн (кларетка) або невдале оновлення (фласка).
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.icon, required this.iconColor, required this.message});

  final IconData icon;
  final Color iconColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.all(m.space3),
        decoration: BoxDecoration(
          color: context.colors.surface2,
          borderRadius: BorderRadius.circular(m.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            SizedBox(width: m.space2 + 2),
            Expanded(child: Text(message, style: context.text.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// Нема чого показати: ні даних, ні кешу. Іконка фласки, повтор кольору манго.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.title, required this.message, required this.onRetry});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(m.space4, m.space6, m.space4, m.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 30, color: context.colors.salve),
            SizedBox(height: m.space3),
            Text(title, style: context.text.titleMedium),
            SizedBox(height: m.space1),
            Text(message, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
            SizedBox(height: m.space4),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Спробувати ще раз'),
            ),
          ],
        ),
      ),
    );
  }
}
