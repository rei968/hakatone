import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Лише портрет: застосунок тримають біля монітора, альбомна орієнтація
  // нічого не дає (специфікація, «Адаптивність»).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Без автоматичних повторів: помилку показуємо одразу з кнопкою «Спробувати ще раз».
  runApp(ProviderScope(retry: (retryCount, error) => null, child: const App()));
}
