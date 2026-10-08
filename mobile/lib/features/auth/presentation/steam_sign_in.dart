import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_context.dart';
import '../application/auth_controller.dart';
import '../data/steam_openid.dart';
import '../domain/steam_session.dart';
import 'steam_web_login.dart';

/// Кнопка «Увійти через Steam» і запасний вхід за Steam ID. Спільні для першого
/// екрана й вкладки «Профіль» у гостя.
class SteamSignInActions extends ConsumerStatefulWidget {
  const SteamSignInActions({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  ConsumerState<SteamSignInActions> createState() => _SteamSignInActionsState();
}

class _SteamSignInActionsState extends ConsumerState<SteamSignInActions> {
  bool _busy = false;
  String? _error;

  Future<void> _steam() async {
    if (kIsWeb) {
      setState(() => _error = 'У браузері вхід через Steam не працює. Відкрийте Android-застосунок або увійдіть за Steam ID.');
      return;
    }
    final openId = ref.read(steamOpenIdProvider);
    final callback = await Navigator.of(context).push<Uri>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => SteamWebLoginPage(openId: openId)),
    );
    if (callback == null || !mounted) return;
    await _run(() async => ref.read(authControllerProvider.notifier).signIn(await openId.verify(callback)));
  }

  Future<void> _manual() async {
    final steamId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SteamIdSheet(),
    );
    if (steamId == null || !mounted) return;
    await _run(() => ref.read(authControllerProvider.notifier).signIn(steamId));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) widget.onSignedIn?.call();
    } on SteamLoginException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.failure) {
              SteamLoginFailure.cancelled => 'Вхід скасовано.',
              SteamLoginFailure.invalid => 'Steam не підтвердив вхід. Спробуйте ще раз.',
              SteamLoginFailure.network => 'Немає зв’язку зі Steam. Перевірте інтернет.',
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('steam-sign-in'),
          onPressed: _busy ? null : _steam,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onSurface,
            foregroundColor: Theme.of(context).colorScheme.surface,
            disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            minimumSize: const Size.fromHeight(52),
          ),
          icon: _busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.surface),
                )
              : const Icon(Icons.sports_esports_rounded, size: 20),
          label: Text(_busy ? 'Перевіряємо вхід…' : 'Увійти через Steam'),
        ),
        SizedBox(height: m.space2),
        Text(
          'Відкриється сторінка Steam. Пароль бачить лише Steam, застосунок отримує тільки ваш Steam ID.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        ),
        if (_error case final error?) ...[
          SizedBox(height: m.space3),
          Semantics(
            liveRegion: true,
            child: Text(error, textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: colors.salve)),
          ),
        ],
        SizedBox(height: m.space1),
        TextButton(
          key: const Key('steam-id-sign-in'),
          onPressed: _busy ? null : _manual,
          child: const Text('Увійти за Steam ID або посиланням'),
        ),
      ],
    );
  }
}

/// Запасний вхід: Steam ID, Friend ID чи посилання на профіль Steam, OpenDota або Dotabuff.
/// Статистика однаково публічна в OpenDota, тож пароль тут не потрібен.
class _SteamIdSheet extends StatefulWidget {
  const _SteamIdSheet();

  @override
  State<_SteamIdSheet> createState() => _SteamIdSheetState();
}

class _SteamIdSheetState extends State<_SteamIdSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final steamId = SteamIds.parse(_controller.text);
    if (steamId == null) {
      setState(() => _error = 'Не схоже на Steam ID. Вставте 17 цифр (7656119…), Friend ID або посилання на профіль.');
      return;
    }
    Navigator.of(context).pop(steamId);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    return Padding(
      padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Вхід за Steam ID', style: context.text.titleMedium),
          SizedBox(height: m.space1),
          Text(
            'Steam ID, Friend ID з Dota 2 або посилання steamcommunity.com/profiles/…, opendota.com/players/…, dotabuff.com/players/…',
            style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
          ),
          SizedBox(height: m.space3),
          TextField(
            key: const Key('steam-id-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(hintText: '76561198…', errorText: _error),
          ),
          SizedBox(height: m.space3),
          FilledButton(
            key: const Key('steam-id-submit'),
            onPressed: _submit,
            child: Text('Увійти', style: TextStyle(fontVariations: wght(FontWeight.w600))),
          ),
        ],
      ),
    );
  }
}
