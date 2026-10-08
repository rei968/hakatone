import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/app_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Лише портрет: застосунок тримають біля монітора, альбомна орієнтація
  // нічого не дає (специфікація, «Адаптивність»).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Сесія й кеш мети — у Hive, щоб застосунок працював і в режимі польоту.
  final storage = await AppStorage.openHive();
  runApp(
    ProviderScope(
      // Без автоматичних повторів: помилку показуємо одразу з кнопкою «Спробувати ще раз».
      retry: (retryCount, error) => null,
      overrides: [appStorageProvider.overrideWithValue(storage)],
      child: const App(),
    ),
  );
}
