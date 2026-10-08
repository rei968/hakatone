import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../auth/application/auth_controller.dart';

enum UpdateStatus { fresh, justSynced, refreshing, offline, failed }

/// «Патч 7.37d · оновлено 12 хв тому» під назвою в шапці.
class UpdatedIndicator extends StatelessWidget {
  const UpdatedIndicator({super.key, required this.status, this.patch, this.updatedAt, required this.now});

  final UpdateStatus status;
  final String? patch;
  final DateTime? updatedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ago = updatedAt == null ? null : Fmt.updatedAgo(updatedAt!, now);
    final withPatch = (patch == null || patch!.isEmpty) ? ago : 'Патч $patch · $ago';
    final (Color dot, String text, Color textColor) = switch (status) {
      UpdateStatus.refreshing => (colors.dust, 'Оновлюємо…', colors.textMuted),
      UpdateStatus.justSynced => (colors.dust, withPatch ?? 'Щойно оновлено', colors.dust),
      UpdateStatus.offline => (
          colors.textSubtle,
          updatedAt == null ? 'Офлайн' : 'Офлайн · дані від ${Fmt.dateTime(updatedAt!)}',
          colors.textMuted,
        ),
      UpdateStatus.failed => (colors.textSubtle, 'Не вдалося оновити', colors.textMuted),
      UpdateStatus.fresh => (colors.success, withPatch ?? '', colors.textMuted),
    };
    return Semantics(
      liveRegion: status == UpdateStatus.justSynced,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: dot, pulse: status == UpdateStatus.refreshing, glow: status == UpdateStatus.justSynced),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulse, required this.glow});

  final Color color;
  final bool pulse;
  final bool glow;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.pulse && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: widget.glow ? [BoxShadow(color: widget.color.withValues(alpha: 0.35), spreadRadius: 3)] : null,
        ),
      ),
    );
  }
}

/// Аватар профілю: перша літера email. Відкриває шторку з виходом.
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).session?.user.email ?? '';
    final colors = context.colors;
    return IconButton(
      tooltip: 'Профіль: $email',
      onPressed: () => _openSheet(context, ref, email),
      icon: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface2,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        child: Text(
          email.isEmpty ? '?' : email.characters.first.toUpperCase(),
          style: context.text.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref, String email) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final m = sheetContext.metrics;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ви увійшли як',
                  style: sheetContext.text.bodySmall?.copyWith(color: sheetContext.colors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(email, style: sheetContext.text.titleMedium),
                SizedBox(height: m.space6),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Вийти'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
