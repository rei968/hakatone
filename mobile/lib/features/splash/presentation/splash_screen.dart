import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/brand.dart';

/// Видно лише, поки читається збережена сесія. Без штучної затримки:
/// роутер сам переходить далі, щойно стан сесії відомий.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Semantics(
        label: 'MangoDota, завантаження',
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colors.mangoSoft, shape: BoxShape.circle),
                    child: const MangoLogo(size: 72),
                  ),
                  const SizedBox(height: 18),
                  Wordmark(style: context.text.headlineMedium?.copyWith(fontSize: 28, height: 34 / 28)),
                  const SizedBox(height: 8),
                  Text(
                    'Мета Dota 2 і AI-білди',
                    style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: colors.dust,
                    backgroundColor: colors.surface2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
