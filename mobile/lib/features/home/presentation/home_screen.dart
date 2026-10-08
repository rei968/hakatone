import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dota/rank.dart';
import '../../../core/format/formatters.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ai_text.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/controls.dart';
import '../../meta/application/meta_controller.dart';
import '../../meta/domain/meta_insights.dart';
import '../../meta/domain/meta_report.dart';
import '../../meta/presentation/meta_screen.dart';
import '../../meta/presentation/widgets/hero_avatar.dart';
import '../../meta/presentation/widgets/meta_header.dart';
import '../../meta/presentation/widgets/tier_section.dart';

/// Головна — дешборд тижня: найкращий і найгірший герой, зміни вінрейту, популярні.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(metaControllerProvider);
    final feed = meta.value;
    final m = context.metrics;
    Future<void> refresh() => ref.read(metaControllerProvider.notifier).refresh();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: m.space4,
        title: Row(
          children: [
            const MangoBadge(),
            SizedBox(width: m.space3),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Wordmark(), LiveUpdatedIndicator()],
              ),
            ),
          ],
        ),
        actions: [const RankChip(), SizedBox(width: m.space4)],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: feed == null
            ? (meta.hasError ? MetaErrorView(error: meta.error!, onRetry: refresh) : const MetaSkeleton())
            : _Dashboard(feed: feed),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.feed});

  final MetaFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.metrics;
    final colors = context.colors;
    final report = feed.report;
    final insights = MetaInsights.of(report);
    final rank = ref.watch(rankProvider);
    final caption = [
      Fmt.weekRange(report.updatedAt ?? feed.savedAt),
      rank.label,
      if (report.totalMatches case final total?) Fmt.matches(total),
    ].join(' · ');
    final label = context.text.labelMedium?.copyWith(color: colors.textMuted);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(m.space4, m.space1, m.space4, m.space8),
      children: [
        if (feed.error != null) ...[MetaFeedBanner(feed: feed), SizedBox(height: m.space3)],
        Text('Тиждень у меті', style: context.text.headlineSmall),
        SizedBox(height: m.space1),
        Text(caption, style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
        SizedBox(height: m.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _HeroStatCard(title: 'Найкращий герой', hero: insights.best)),
            SizedBox(width: m.space2),
            Expanded(child: _HeroStatCard(title: 'Найгірший герой', hero: insights.worst)),
          ],
        ),
        if (insights.hasDeltas) ...[
          SizedBox(height: m.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HeroStatCard(title: 'Найбільший зліт', hero: insights.risers.firstOrNull, showDelta: true)),
              SizedBox(width: m.space2),
              Expanded(child: _HeroStatCard(title: 'Найбільше падіння', hero: insights.fallers.firstOrNull, showDelta: true)),
            ],
          ),
          if (insights.risers.isNotEmpty || insights.fallers.isNotEmpty) ...[
            SizedBox(height: m.space6),
            Text('Зміни вінрейту за тиждень', style: label),
            SizedBox(height: m.space2),
            _DeltaCard(heroes: [...insights.risers, ...insights.fallers]),
          ],
        ],
        SizedBox(height: m.space6),
        Text('Найпопулярніші цього тижня', style: label),
        SizedBox(height: m.space2),
        Wrap(
          spacing: m.space2 - 2,
          runSpacing: m.space2 - 2,
          children: [for (final hero in insights.popular) _PopularChip(hero: hero)],
        ),
        if (insights.best?.aiSummary case final summary?) ...[
          SizedBox(height: m.space6),
          Container(
            padding: EdgeInsets.all(m.space3),
            decoration: BoxDecoration(color: colors.smokeSoft, borderRadius: BorderRadius.circular(m.radiusLg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Чому ${insights.best!.name} зараз сильний', style: context.text.labelLarge),
                SizedBox(height: m.space1),
                AiText(summary),
              ],
            ),
          ),
        ],
        SizedBox(height: m.space6),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.meta),
          icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
          label: Text('Уся мета · ${Fmt.heroes(report.heroes.length)}'),
        ),
      ],
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({required this.title, required this.hero, this.showDelta = false});

  final String title;
  final MetaHero? hero;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final h = hero;
    final number = context.text.labelSmall!.copyWith(fontSize: 14, height: 18 / 14);
    return Card(
      child: InkWell(
        onTap: h == null ? null : () => context.push(AppRoutes.hero(h.id)),
        child: Padding(
          padding: EdgeInsets.all(m.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
              SizedBox(height: m.space2),
              if (h == null)
                Text('Без змін', style: context.text.bodyMedium?.copyWith(color: colors.textMuted))
              else
                Row(
                  children: [
                    HeroAvatar(name: h.name, attribute: h.primaryAttribute, url: h.avatarUrl, size: 32),
                    SizedBox(width: m.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600)),
                          ),
                          // Wrap, а не Row: на 320 dp дельта переноситься під вінрейт.
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!showDelta) Text(Fmt.percent(h.winRate), style: number.copyWith(color: winRateColor(context, h.winRate))),
                              if (h.winRateDelta case final delta?) DeltaText(delta, style: showDelta ? number : null),
                              if (showDelta) Text('п.п.', style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Рядки зі смужкою від центру: вправо — зліт, вліво — падіння.
class _DeltaCard extends StatelessWidget {
  const _DeltaCard({required this.heroes});

  final List<MetaHero> heroes;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final maxAbs = heroes.fold<double>(0.1, (max, h) => h.winRateDelta!.abs() > max ? h.winRateDelta!.abs() : max);
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: m.space3, vertical: m.space1),
        child: Column(
          children: [
            for (var i = 0; i < heroes.length; i++) ...[
              if (i > 0) const Divider(),
              InkWell(
                onTap: () => context.push(AppRoutes.hero(heroes[i].id)),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: m.space2),
                  child: Row(
                    children: [
                      HeroAvatar(name: heroes[i].name, attribute: heroes[i].primaryAttribute, url: heroes[i].avatarUrl, size: 24),
                      SizedBox(width: m.space2),
                      Expanded(child: Text(heroes[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium)),
                      SizedBox(
                        width: 72,
                        height: 6,
                        child: Stack(
                          children: [
                            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(3)))),
                            Align(
                              alignment: heroes[i].winRateDelta! >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                child: Align(
                                  alignment: heroes[i].winRateDelta! >= 0 ? Alignment.centerRight : Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: (heroes[i].winRateDelta!.abs() / maxAbs).clamp(0.05, 1.0),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: heroes[i].winRateDelta! >= 0 ? colors.tango : colors.salve,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 46, child: Align(alignment: Alignment.centerRight, child: DeltaText(heroes[i].winRateDelta!))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PopularChip extends StatelessWidget {
  const _PopularChip({required this.hero});

  final MetaHero hero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface1,
      shape: StadiumBorder(side: BorderSide(color: colors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.hero(hero.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(child: HeroAvatar(name: hero.name, attribute: hero.primaryAttribute, url: hero.avatarUrl, size: 24)),
              const SizedBox(width: 6),
              Text(hero.name, style: context.text.bodySmall),
              const SizedBox(width: 6),
              Text(Fmt.percent(hero.pickRate), style: context.text.labelSmall?.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
