import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dota/dota_assets.dart';
import '../../../core/format/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/dota_icons.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/steam_session.dart';
import '../../auth/presentation/steam_sign_in.dart';
import '../application/profile_providers.dart';
import '../domain/player.dart';
import 'hero_pool_chart.dart';

/// Профіль гравця з OpenDota: пул героїв, вінрейт, KDA, GPM за період, історія матчів у шторці.
/// Гість бачить тут вхід через Steam.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль'),
        actions: [
          if (session != null)
            IconButton(
              tooltip: 'Вийти',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _confirmSignOut(context, ref),
            ),
        ],
      ),
      body: session == null ? const _GuestProfile() : _SignedInProfile(session: session),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
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
                Text('Вийти з акаунта Steam?', style: sheetContext.text.titleMedium),
                SizedBox(height: m.space1),
                Text(
                  'Мета й білди лишаться доступні, профіль попросить увійти знову.',
                  style: sheetContext.text.bodyMedium?.copyWith(color: sheetContext.colors.textMuted),
                ),
                SizedBox(height: m.space4),
                OutlinedButton.icon(
                  key: const Key('sign-out'),
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

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    return ListView(
      padding: EdgeInsets.fromLTRB(m.space6, m.space6, m.space6, m.space8),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.mangoSoft, shape: BoxShape.circle),
            child: const MangoLogo(size: 48),
          ),
        ),
        SizedBox(height: m.space4),
        Text('Твоя статистика з Dota 2', textAlign: TextAlign.center, style: context.text.titleLarge),
        SizedBox(height: m.space2),
        Text(
          'Увійди через Steam, щоб бачити свій пул героїв, вінрейт, KDA, GPM та історію матчів за 25 чи 100 ігор, тиждень, місяць або патч.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
        ),
        SizedBox(height: m.space6),
        const SteamSignInActions(),
      ],
    );
  }
}

class _SignedInProfile extends ConsumerWidget {
  const _SignedInProfile({required this.session});

  final SteamSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.metrics;
    final period = ref.watch(profilePeriodProvider);
    final matches = ref.watch(playerMatchesProvider(period));
    Future<void> refresh() async {
      ref.invalidate(playerProfileProvider);
      await ref.refresh(playerMatchesProvider(period).future).catchError((Object _) => const Fetched(<PlayerMatch>[]));
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space8),
        children: [
          _ProfileHeader(session: session),
          SizedBox(height: m.space4),
          SegmentedTabs<ProfilePeriod>(
            values: ProfilePeriod.values,
            selected: period,
            label: (p) => p.label,
            onChanged: ref.read(profilePeriodProvider.notifier).select,
          ),
          SizedBox(height: m.space4),
          ...matches.when(
            data: (fetched) => _summary(context, fetched, period),
            loading: () => [
              const SlowHint(after: Duration(seconds: 4), text: 'OpenDota збирає твої матчі. Буває до 20 секунд.'),
              SizedBox(height: m.space3),
              const AppSkeleton(height: 210, radius: 16),
              SizedBox(height: m.space4),
              const AppSkeleton(height: 76, radius: 16),
            ],
            error: (error, _) => [
              ErrorState(
                title: 'Не вдалося завантажити матчі',
                message: loadErrorMessage(error),
                onRetry: () => ref.invalidate(playerMatchesProvider(period)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _summary(BuildContext context, Fetched<List<PlayerMatch>> fetched, ProfilePeriod period) {
    final m = context.metrics;
    final colors = context.colors;
    final matches = fetched.value;
    final summary = ProfileSummary.of(matches);
    return [
      if (fetched.fromCache) ...[
        StatusBanner(
          icon: isOfflineError(fetched.staleError) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          iconColor: isOfflineError(fetched.staleError) ? colors.clarity : colors.salve,
          message: 'Показуємо статистику, збережену ${Fmt.dateTime(fetched.savedAt!)}.',
        ),
        SizedBox(height: m.space3),
      ],
      if (matches.isEmpty)
        Card(
          child: Padding(
            padding: EdgeInsets.all(m.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Матчів за ${period.caption} немає', style: context.text.titleMedium),
                SizedBox(height: m.space1),
                Text(
                  'Якщо ти грав, перевір у Dota 2: Налаштування → Соціальне → «Відкрита історія матчів». '
                  'OpenDota бачить лише відкриті профілі.',
                  style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        )
      else ...[
        Text(
          'Пул героїв · ${Fmt.heroes(summary.heroPool.length)} за ${Fmt.games(summary.games)}',
          style: context.text.labelMedium?.copyWith(color: colors.textMuted),
        ),
        SizedBox(height: m.space2),
        HeroPoolChart(pool: summary.heroPool),
        SizedBox(height: m.space2),
        Wrap(
          spacing: m.space3,
          runSpacing: m.space1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Legend(color: colors.tango, text: 'вінрейт ≥ 55%'),
            _Legend(color: colors.dust, text: '45–55%'),
            _Legend(color: colors.salve, text: '≤ 45%'),
            Text('розмір — кількість ігор', style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
          ],
        ),
        SizedBox(height: m.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Kpi(
                label: 'Вінрейт',
                value: '${summary.winRate.round()}%',
                valueColor: summary.winRate >= 52 ? colors.tango : (summary.winRate <= 48 ? colors.salve : null),
                caption: '${summary.wins}–${summary.losses}',
              ),
            ),
            SizedBox(width: m.space2),
            Expanded(
              child: _Kpi(
                label: 'KDA',
                value: summary.kda.toStringAsFixed(1).replaceAll('.', ','),
                caption: '${summary.kills.round()}/${summary.deaths.round()}/${summary.assists.round()}',
              ),
            ),
            SizedBox(width: m.space2),
            Expanded(
              child: _Kpi(
                label: 'GPM',
                value: summary.gpm == null ? '—' : '${summary.gpm!.round()}',
                caption: summary.xpm == null ? '' : 'XPM ${summary.xpm!.round()}',
              ),
            ),
          ],
        ),
        SizedBox(height: m.space3),
        Card(
          child: ListTile(
            key: const Key('match-history'),
            leading: const Icon(Icons.history_rounded),
            title: const Text('Історія матчів'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${matches.length}', style: context.text.labelSmall?.copyWith(color: colors.textMuted)),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
            onTap: () => showMatchHistory(context, matches, period),
          ),
        ),
      ],
    ];
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.session});

  final SteamSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final m = context.metrics;
    final profile = ref.watch(playerProfileProvider).value?.value;
    final name = profile?.name ?? session.personaName ?? 'Гравець ${session.accountId}';
    final avatar = profile?.avatarUrl ?? session.avatarUrl;
    final medal = profile?.medal;
    return Row(
      children: [
        ClipOval(
          child: SizedBox.square(
            dimension: 52,
            child: NetworkPicture(url: avatar, fallback: Initials(name, fontSize: 16)),
          ),
        ),
        SizedBox(width: m.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              Text(
                profile == null || profile.totalMatches == 0
                    ? 'Steam · ID ${session.accountId}'
                    : 'Steam · ${Fmt.matches(profile.totalMatches)}',
                style: context.text.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
        if (medal != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: colors.mangoSoft, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.military_tech_rounded, size: 16, color: colors.mango),
                const SizedBox(width: 4),
                Text(medal, style: context.text.labelMedium?.copyWith(color: colors.mango)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        ),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodySmall?.copyWith(color: context.colors.textMuted)),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.caption, this.valueColor});

  final String label;
  final String value;
  final String caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.metrics.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
            Text(
              value,
              style: context.text.labelSmall?.copyWith(
                fontSize: 18,
                height: 24 / 18,
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontVariations: wght(FontWeight.w600),
              ),
            ),
            Text(caption, maxLines: 1, style: context.text.bodySmall?.copyWith(color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Шторка «Історія матчів» з профілю.
Future<void> showMatchHistory(BuildContext context, List<PlayerMatch> matches, ProfilePeriod period) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        final m = context.metrics;
        final now = DateTime.now();
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space2),
              child: Row(
                children: [
                  Expanded(child: Text('Історія матчів', style: context.text.titleMedium)),
                  Text(period.caption, style: context.text.bodySmall?.copyWith(color: context.colors.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space6),
                itemCount: matches.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, i) => _MatchRow(match: matches[i], now: now),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MatchRow extends ConsumerWidget {
  const _MatchRow({required this.match, required this.now});

  final PlayerMatch match;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final m = context.metrics;
    final hero = ref.watch(dotaAssetsProvider).value?.hero(match.heroId);
    final name = hero?.name ?? 'Герой ${match.heroId}';
    final result = match.won ? 'Перемога' : 'Поразка';
    final kda = '${match.kills}/${match.deaths}/${match.assists}';
    return Semantics(
      label: '$result на $name, ${Fmt.ago(match.startTime, now)}, KDA $kda',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: m.space2),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(color: match.won ? colors.tango : colors.salve, borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(width: m.space2),
            ClipRRect(
              borderRadius: BorderRadius.circular(m.radiusSm),
              child: SizedBox(
                width: 48,
                height: 27,
                child: NetworkPicture(url: hero?.imageUrl, fallback: Initials(name)),
              ),
            ),
            SizedBox(width: m.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$result · $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600)),
                  ),
                  Text(
                    '${Fmt.ago(match.startTime, now)} · ${Fmt.clock(match.duration)}',
                    style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(kda, style: context.text.labelSmall),
                if (match.gpm case final gpm?)
                  Text('$gpm GPM', style: context.text.labelSmall?.copyWith(fontSize: 10, color: colors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
