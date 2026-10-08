import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/meta/application/meta_controller.dart';
import '../theme/theme_context.dart';

/// Нижнє меню: Головна · Мета · Профіль. Вкладки зберігають свій стан і прокрутку.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Повернулися в застосунок (наприклад, після `/admin/sync` на демо) — тягнемо свіжу мету.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(metaControllerProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.border))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          // Повторне натискання на активну вкладку повертає її на початок.
          onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Головна'),
            NavigationDestination(
              icon: Icon(Icons.format_list_numbered_rounded),
              selectedIcon: Icon(Icons.format_list_numbered_rounded),
              label: 'Мета',
            ),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Профіль'),
          ],
        ),
      ),
    );
  }
}
