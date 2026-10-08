import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/states.dart';
import '../application/meta_controller.dart';
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

  /// Після вдалого оновлення: індикатор кольору дасту і спалах рядків — на хвилину.
  bool _justSynced = false;
  Timer? _syncedTimer;

  /// «Оновлено X хв тому» перераховується сам, без дій гравця.
  late final Timer _clock;

  /// Повернулися в застосунок (наприклад, після `/admin/sync` на демо) — тягнемо свіжу мету.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _clock.cancel();
    _syncedTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(metaControllerProvider.notifier).refresh();
    if (!mounted) return;
    final meta = ref.read(metaControllerProvider);
    final synced = !meta.hasError && meta.value?.error == null;
    setState(() => _justSynced = synced);
    _syncedTimer?.cancel();
    if (synced) {
      _syncedTimer = Timer(const Duration(minutes: 1), () {
        if (mounted) setState(() => _justSynced = false);
      });
    }
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
    final feed = meta.value;
    final report = feed?.report;
    final colors = context.colors;
    final m = context.metrics;

    final status = switch (feed) {
      _ when meta.isLoading || (feed?.refreshing ?? false) => UpdateStatus.refreshing,
      null => UpdateStatus.failed,
      MetaFeed(offline: true) => UpdateStatus.offline,
      MetaFeed(error: != null) => UpdateStatus.failed,
      _ when _justSynced => UpdateStatus.justSynced,
      _ => UpdateStatus.fresh,
    };

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
                    savedAt: feed?.savedAt,
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
          child: feed == null
              ? (meta.hasError ? _error(meta.error!) : _skeleton())
              : _content(feed),
        ),
      ),
    );
  }

  /// Ліниві слайвери: героїв 127, тож рядки й аватари будуються лише
  /// тоді, коли докручуються до екрана.
  Widget _content(MetaFeed feed) {
    final m = context.metrics;
    final colors = context.colors;
    final report = feed.report;
    final saved = Fmt.dateTime(feed.savedAt);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (feed.error != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(m.space4, m.space1, m.space4, 0),
            sliver: SliverToBoxAdapter(
              child: feed.offline
                  ? StatusBanner(
                      icon: Icons.wifi_off_rounded,
                      iconColor: colors.clarity,
                      message: 'Немає інтернету. Показуємо мету, збережену на пристрої $saved.',
                    )
                  : StatusBanner(
                      icon: Icons.error_outline_rounded,
                      iconColor: colors.salve,
                      message: 'Не вдалося оновити мету: ${loadErrorMessage(feed.error!).toLowerCase()} '
                          'Показуємо дані від $saved.',
                    ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(m.space4, m.space4, m.space4, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text('Мета героїв', style: context.text.headlineSmall)),
                Text(Fmt.heroes(report.heroes.length), style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
        ),
        for (final (tier, heroes) in report.byTier) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(m.space4, m.space6, m.space4, 10),
            sliver: SliverToBoxAdapter(child: TierHeader(tier: tier, count: heroes.length)),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: m.space4),
            sliver: DecoratedSliver(
              decoration: BoxDecoration(
                color: colors.surface1,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(m.radiusXl),
              ),
              sliver: SliverList.builder(
                itemCount: heroes.length,
                itemBuilder: (context, i) => Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      if (i > 0) const Divider(indent: 72),
                      MetaHeroRow(hero: heroes[i], flash: _justSynced),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: m.space8)),
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
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(m.space4, m.space3, m.space4, 0),
            child: const SlowHint(
              after: Duration(seconds: 6),
              text: 'Сервер прокидається після сну. Перший запит може тривати до хвилини.',
            ),
          ),
          section(),
          section(),
        ],
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
