import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/api_meta_repository.dart';
import '../data/meta_repository.dart';
import '../domain/meta_report.dart';

final metaRepositoryProvider = Provider<MetaRepository>(
  (ref) => AppConfig.useMocks ? MockMetaRepository() : ApiMetaRepository(ref.watch(dioProvider)),
);

/// Мета героїв. Під час оновлення Riverpod лишає попередні дані
/// (`isRefreshing`), тож список не зникає під pull-to-refresh.
class MetaController extends AsyncNotifier<MetaReport> {
  @override
  Future<MetaReport> build() => ref.read(metaRepositoryProvider).fetchMeta();

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Помилка вже лежить у state, екран покаже її поверх старих даних.
    }
  }
}

final metaControllerProvider = AsyncNotifierProvider<MetaController, MetaReport>(MetaController.new);
