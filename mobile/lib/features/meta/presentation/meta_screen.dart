import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dota/rank.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/states.dart';
import '../application/meta_controller.dart';
import '../domain/hero_attribute.dart';
import '../domain/meta_insights.dart';
import '../domain/tier.dart';
import 'widgets/meta_header.dart';
import 'widgets/tier_section.dart';

/// Мета героїв як таблиця Dotabuff: пошук, фільтр атрибута, сортування, ранг.
class MetaScreen extends ConsumerStatefulWidget {
  const MetaScreen({super.key});

  @override
  ConsumerState<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends ConsumerState<MetaScreen> {
  final _search = TextEditingController();
  HeroAttribute? _attribute;
  MetaSort _sort = MetaSort.tier;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(metaControllerProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaControllerProvider);
    final feed = meta.value;
    final m = context.metrics;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: m.space4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text('Мета героїв', style: context.text.titleLarge), const LiveUpdatedIndicator()],
        ),
        actions: [const RankChip(), SizedBox(width: m.space4)],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: feed == null
            ? (meta.hasError ? MetaErrorView(error: meta.error!, onRetry: _refresh) : const MetaSkeleton())
            : _content(feed),
      ),
    );
  }

  Widget _content(MetaFeed feed) {
    final m = context.metrics;
    final colors = context.colors;
    final rank = ref.watch(rankProvider);
    final heroes = queryHeroes(feed.report.heroes, search: _search.text, attribute: _attribute, sort: _sort);
    final rankIgnored = rank != Rank.all && feed.report.rank != rank.apiValue;

    final rows = <Widget>[];
    Tier? group;
    for (final hero in heroes) {
      if (_sort == MetaSort.tier && hero.tier != group) {
        group = hero.tier;
        final count = heroes.where((h) => h.tier == group).length;
        if (rows.isNotEmpty) rows.add(const Divider());
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(m.space3, m.space3, m.space3, m.space1),
          child: Row(
            children: [
              TierBadge(tier: hero.tier, size: 22),
              SizedBox(width: m.space2),
              Expanded(
                child: Text(
                  '${hero.tier.title} · ${hero.tier.description.toLowerCase()} · ${Fmt.heroes(count)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ));
      } else if (rows.isNotEmpty) {
        rows.add(const Divider(indent: 64));
      }
      rows.add(MetaTableRow(hero: hero));
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(m.space4, m.space1, m.space4, 0),
          sliver: SliverList.list(children: [
            if (feed.error != null) ...[
              MetaFeedBanner(feed: feed),
              SizedBox(height: m.space3),
            ],
            if (rankIgnored) ...[
              StatusBanner(
                icon: Icons.info_outline_rounded,
                iconColor: colors.clarity,
                message: 'Сервер поки рахує мету за всі ранги, тому цифри для ${rank.label} ті самі.',
              ),
              SizedBox(height: m.space3),
            ],
            TextField(
              key: const Key('meta-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Знайти героя',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистити',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            SizedBox(height: m.space2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final attribute in <HeroAttribute?>[null, ...HeroAttribute.values])
                    Padding(
                      padding: EdgeInsets.only(right: m.space2 - 2),
                      child: ChoiceChip(
                        label: Text(attribute?.label ?? 'Усі'),
                        selected: _attribute == attribute,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _attribute = attribute),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: m.space2),
            SegmentedTabs<MetaSort>(
              values: MetaSort.values,
              selected: _sort,
              label: (s) => s.label,
              onChanged: (s) => setState(() => _sort = s),
            ),
            SizedBox(height: m.space3),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: m.space3),
              child: DefaultTextStyle(
                style: context.text.labelMedium!.copyWith(color: colors.textMuted),
                child: Row(
                  children: [
                    Expanded(child: Text('Герой · ${heroes.length}')),
                    SizedBox(width: 60, child: Text(_sort == MetaSort.winRate ? 'Він ↓' : 'Він', textAlign: TextAlign.end)),
                    SizedBox(width: 52, child: Text(_sort == MetaSort.pickRate ? 'Пік ↓' : 'Пік', textAlign: TextAlign.end)),
                  ],
                ),
              ),
            ),
            SizedBox(height: m.space1),
          ]),
        ),
        if (heroes.isEmpty)
          SliverPadding(
            padding: EdgeInsets.all(m.space4),
            sliver: SliverToBoxAdapter(
              child: Text(
                _search.text.trim().isEmpty ? 'Немає героїв з цим атрибутом.' : 'Нічого не знайдено за «${_search.text.trim()}».',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: m.space4),
            sliver: DecoratedSliver(
              decoration: BoxDecoration(
                color: colors.surface1,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(m.radiusXl),
              ),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => Material(type: MaterialType.transparency, child: rows[i]),
              ),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: m.space8)),
      ],
    );
  }
}

/// Банер, коли показуємо збережену мету: офлайн або сервер не відповів.
class MetaFeedBanner extends StatelessWidget {
  const MetaFeedBanner({super.key, required this.feed});

  final MetaFeed feed;

  @override
  Widget build(BuildContext context) {
    final saved = Fmt.dateTime(feed.savedAt);
    return feed.offline
        ? StatusBanner(
            icon: Icons.wifi_off_rounded,
            iconColor: context.colors.clarity,
            message: 'Немає інтернету. Показуємо мету, збережену на пристрої $saved.',
          )
        : StatusBanner(
            icon: Icons.error_outline_rounded,
            iconColor: context.colors.salve,
            message: 'Не вдалося оновити мету: ${loadErrorMessage(feed.error!).toLowerCase()} Показуємо дані від $saved.',
          );
  }
}

/// Ні мети, ні кешу: помилка з повтором.
class MetaErrorView extends StatelessWidget {
  const MetaErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(context.metrics.space4),
      children: [
        ErrorState(
          title: 'Не вдалося завантажити мету',
          message: '${loadErrorMessage(error)} Щойно дані завантажаться, вони працюватимуть і без мережі.',
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class MetaSkeleton extends StatelessWidget {
  const MetaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Semantics(
      label: 'Завантаження мети',
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(m.space4),
        children: [
          const SlowHint(
            after: Duration(seconds: 6),
            text: 'Сервер прокидається після сну. Перший запит може тривати до хвилини.',
          ),
          SizedBox(height: m.space3),
          const AppSkeleton(height: 48, radius: 12),
          SizedBox(height: m.space4),
          for (var i = 0; i < 7; i++) ...[
            Row(
              children: [
                AppSkeleton(width: 40, height: 40, radius: m.radiusMd),
                SizedBox(width: m.space3),
                const Expanded(child: AppSkeleton(height: 14)),
                SizedBox(width: m.space6),
                const AppSkeleton(width: 48, height: 14),
              ],
            ),
            SizedBox(height: m.space4),
          ],
        ],
      ),
    );
  }
}
