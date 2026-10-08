import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/brand.dart';
import '../application/auth_controller.dart';
import 'steam_sign_in.dart';

/// Перший екран нового гравця і вхід з профілю: Steam або «Продовжити без входу».
class SteamLoginScreen extends ConsumerWidget {
  const SteamLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstLaunch = !ref.watch(authControllerProvider.select((s) => s.welcomed));
    final colors = context.colors;
    final m = context.metrics;
    return Scaffold(
      appBar: firstLaunch
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: 'Закрити',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile),
              ),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: m.space6),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: m.space8),
                  Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.mangoSoft, shape: BoxShape.circle),
                        child: const MangoLogo(size: 60),
                      ),
                      SizedBox(height: m.space4),
                      Wordmark(style: context.text.headlineMedium),
                      SizedBox(height: m.space2),
                      Text(
                        'Мета, білди і твоя статистика',
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                  SizedBox(height: m.space8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Після входу роутер сам переводить у профіль.
                      const SteamSignInActions(),
                      if (firstLaunch)
                        TextButton(
                          key: const Key('continue-as-guest'),
                          onPressed: () async {
                            await ref.read(authControllerProvider.notifier).continueAsGuest();
                            if (context.mounted) context.go(AppRoutes.home);
                          },
                          child: const Text('Продовжити без входу'),
                        ),
                      SizedBox(height: m.space4),
                      Text(
                        'Статистика видна, якщо в налаштуваннях Dota 2 увімкнено «Відкрита історія матчів».',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(color: colors.textSubtle),
                      ),
                      SizedBox(height: m.space4),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
