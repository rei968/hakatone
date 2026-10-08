import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/states.dart';
import '../application/meta_controller.dart';
import '../domain/meta_report.dart';
import 'widgets/meta_header.dart';
import 'widgets/tier_section.dart';

/// Головний екран — мета героїв за тірами (docs/design/01-main-menu.html).
class MetaScreen extends ConsumerStatefulWidget {
  const MetaScreen({super.key});

  @override
  ConsumerState<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends ConsumerState<MetaScreen> {
  bool _scrolled = false;

  /// Після вдалого pull-to-refresh: індикатор «щойно оновлено» і спалах рядків.
  bool _justSynced = false;

  Future<void> _refresh() async {
    await ref.read(metaControllerProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _justSynced = !ref.read(metaControllerProvider).hasError);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final scrolled = notification.metrics.pixels > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaControllerProvider);
    final report = meta.value;
    final colors = context.colors;
    final m = context.metrics;

    final status = meta.isLoading
        ? UpdateStatus.refreshing
        : meta.hasError
            ? UpdateStatus.failed
            : _justSynced
                ? UpdateStatus.justSynced
                : UpdateStatus.fresh;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: m.space4,
        shape: Border(bottom: BorderSide(color: _scrolled ? colors.border : Colors.transparent)),
        title: Row(
          children: [
            const MangoBadge(),
            SizedBox(width: m.space3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(),
                  UpdatedIndicator(
                    status: status,
                    patch: report?.patch,
                    updatedAt: report?.updatedAt,
                    now: DateTime.now(),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [const ProfileButton(), SizedBox(width: m.space1)],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: report == null
              ? (meta.hasError ? _error(meta.error!) : _skeleton())
              : _content(report, refreshFailed: meta.hasError),
        ),
      ),
    );
  }

  Widget _content(MetaReport report, {required bool refreshFailed}) {
    final m = context.metrics;
    final groups = report.byTier;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: m.space8),
      children: [
        if (refreshFailed)
          Padding(
            padding: EdgeInsets.fromLTRB(m.space4, m.space1, m.space4, 0),
            child: StatusBanner(
              icon: Icons.error_outline_rounded,
              iconColor: context.colors.salve,
              message: 'Не вдалося оновити мету. Показуємо попередні дані.',
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(m.space4, m.space4, m.space4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Мета героїв', style: context.text.headlineSmall)),
              Text(
                Fmt.heroes(report.heroes.length),
                style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
              ),
            ],
          ),
        ),
        for (final (tier, heroes) in groups) ...[
          SizedBox(height: m.space6),
          TierSection(tier: tier, heroes: heroes, flash: _justSynced),
        ],
      ],
    );
  }

  Widget _skeleton() {
    final m = context.metrics;
    Widget row() => Padding(
          padding: EdgeInsets.fromLTRB(m.space3, 14, m.space3, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: m.thumb, height: m.thumb, radius: m.radiusMd),
              SizedBox(width: m.space3),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(widthFactor: 0.46, child: AppSkeleton(height: 14)),
                    SizedBox(height: 6),
                    FractionallySizedBox(widthFactor: 0.62, child: AppSkeleton(height: 11)),
                    SizedBox(height: 10),
                    AppSkeleton(height: 11),
                  ],
                ),
              ),
              SizedBox(width: m.space3),
              const AppSkeleton(width: 48, height: 16),
            ],
          ),
        );
    Widget section() => Padding(
          padding: EdgeInsets.fromLTRB(m.space4, m.space6, m.space4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSkeleton(width: 32, height: 32, radius: 9),
                  SizedBox(width: 12),
                  AppSkeleton(width: 120, height: 14),
                ],
              ),
              const SizedBox(height: 10),
              Card(child: Column(children: [row(), const Divider(indent: 72), row(), const Divider(indent: 72), row()])),
            ],
          ),
        );
    return Semantics(
      label: 'Завантаження мети',
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [section(), section()],
      ),
    );
  }

  Widget _error(Object error) {
    final m = context.metrics;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(m.space4),
      children: [
        SizedBox(height: m.space4),
        ErrorState(
          title: 'Не вдалося завантажити мету',
          message: '${loadErrorMessage(error)} Щойно дані завантажаться, вони працюватимуть і без мережі.',
          onRetry: _refresh,
        ),
      ],
    );
  }
}
