import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context.dart';
import '../application/update_controller.dart';
import '../domain/app_release.dart';

/// Обгортає застосунок: після старту тихо перевіряє GitHub Releases і, якщо є новіша
/// версія, пропонує її встановити. Сам екран застосунку не змінюється.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  /// Пауза після старту, щоб не перебивати splash і вхід.
  static const startDelay = Duration(seconds: 3);

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(UpdateGate.startDelay, _check);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final update = await ref.read(updateCheckerProvider).check();
    final context = rootNavigatorKey.currentContext;
    if (update == null || !mounted || context == null || !context.mounted) return;
    await showDialog<void>(context: context, builder: (_) => _UpdateDialog(update: update));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.update});

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context) {
    final notes = update.release.notes;
    return AlertDialog(
      title: const Text('Доступна нова версія'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MangoDota ${update.release.version} готова до встановлення. У вас ${update.currentVersion}.'),
          if (notes != null) ...[
            SizedBox(height: context.metrics.space3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(notes, style: context.text.bodySmall?.copyWith(color: context.colors.textMuted)),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Пізніше')),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _DownloadDialog(release: update.release),
            );
          },
          child: const Text('Оновити'),
        ),
      ],
    );
  }
}

/// Завантажує APK і віддає його системному інсталятору (плагін ota_update).
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.release});

  final AppRelease release;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  StreamSubscription<OtaEvent>? _subscription;
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() {
      _progress = null;
      _error = null;
    });
    try {
      _subscription = OtaUpdate()
          .execute(
            widget.release.apkUrl,
            destinationFilename: 'MangoDota-${widget.release.version}.apk',
            sha256checksum: widget.release.sha256,
          )
          .listen(_onEvent, onError: (Object _) => _fail(OtaStatus.INTERNAL_ERROR));
    } catch (_) {
      _fail(OtaStatus.INTERNAL_ERROR);
    }
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _progress = (double.tryParse(event.value ?? '') ?? 0) / 100);
      case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
        // Далі — системне вікно встановлення.
        Navigator.of(context).pop();
      case final status:
        _fail(status);
    }
  }

  void _fail(OtaStatus status) {
    if (!mounted) return;
    setState(() => _error = switch (status) {
          OtaStatus.PERMISSION_NOT_GRANTED_ERROR =>
            'Дозвольте MangoDota встановлювати застосунки: Налаштування → Застосунки → MangoDota → Встановлення невідомих застосунків.',
          OtaStatus.CHECKSUM_ERROR => 'Файл оновлення пошкоджений. Спробуйте ще раз.',
          OtaStatus.INSTALLATION_ERROR =>
            'Android не встановив оновлення. Якщо застосунок ставили не з GitHub Releases, видаліть його й установіть нову версію вручну.',
          OtaStatus.CANCELED => 'Завантаження скасовано.',
          _ => 'Не вдалося завантажити оновлення. Перевірте інтернет і спробуйте ще раз.',
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text(error == null ? 'Завантажуємо ${widget.release.version}' : 'Оновлення не вдалося'),
      content: error == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _progress),
                SizedBox(height: context.metrics.space3),
                Text(_progress == null ? 'Підключаємось до GitHub…' : '${(_progress! * 100).round()}%'),
              ],
            )
          : Text(error),
      actions: [
        TextButton(
          onPressed: () {
            if (error == null) OtaUpdate().cancel();
            Navigator.of(context).pop();
          },
          child: Text(error == null ? 'Скасувати' : 'Закрити'),
        ),
        if (error != null)
          FilledButton(
            onPressed: () {
              _subscription?.cancel();
              _start();
            },
            child: const Text('Спробувати ще раз'),
          ),
      ],
    );
  }
}
