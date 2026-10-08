import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/theme_context.dart';
import '../../application/meta_controller.dart';

enum UpdateStatus { fresh, justSynced, refreshing, offline, failed }

/// «Патч 7.37d · оновлено 12 хв тому» під назвою в шапці.
class UpdatedIndicator extends StatelessWidget {
  const UpdatedIndicator({
    super.key,
    required this.status,
    this.patch,
    this.updatedAt,
    this.savedAt,
    required this.now,
  });

  final UpdateStatus status;
  final String? patch;

  /// Коли бекенд перерахував мету.
  final DateTime? updatedAt;

  /// Коли дані потрапили на пристрій — для «Офлайн · дані від …».
  final DateTime? savedAt;
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
          (savedAt ?? updatedAt) == null ? 'Офлайн' : 'Офлайн · дані від ${Fmt.dateTime((savedAt ?? updatedAt)!)}',
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

/// Стан індикатора з мети. [now] — щоб «щойно оновлено» гасло саме.
UpdateStatus metaUpdateStatus(AsyncValue<MetaFeed> meta, DateTime now) {
  final feed = meta.value;
  return switch (feed) {
    _ when meta.isLoading || (feed?.refreshing ?? false) => UpdateStatus.refreshing,
    null => UpdateStatus.failed,
    MetaFeed(offline: true) => UpdateStatus.offline,
    MetaFeed(error: != null) => UpdateStatus.failed,
    _ when feed.justSynced(now) => UpdateStatus.justSynced,
    _ => UpdateStatus.fresh,
  };
}

/// [UpdatedIndicator] для поточної мети, що сам перераховується кожні 30 с.
class LiveUpdatedIndicator extends ConsumerStatefulWidget {
  const LiveUpdatedIndicator({super.key});

  @override
  ConsumerState<LiveUpdatedIndicator> createState() => _LiveUpdatedIndicatorState();
}

class _LiveUpdatedIndicatorState extends ConsumerState<LiveUpdatedIndicator> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaControllerProvider);
    final feed = meta.value;
    final now = DateTime.now();
    return UpdatedIndicator(
      status: metaUpdateStatus(meta, now),
      patch: feed?.report.patch,
      updatedAt: feed?.report.updatedAt,
      savedAt: feed?.savedAt,
      now: now,
    );
  }
}
