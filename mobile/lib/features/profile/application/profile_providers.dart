import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/player.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => OpenDotaProfileRepository(ref.watch(externalDioProvider)),
);

/// Дані з мережі або, якщо її немає, збережені раніше.
@immutable
class Fetched<T> {
  const Fetched(this.value, {this.savedAt, this.staleError});

  final T value;

  /// Коли збережено показані дані; `null` — свіжа відповідь.
  final DateTime? savedAt;
  final Object? staleError;

  bool get fromCache => staleError != null;
}

/// Спершу мережа, без неї — кеш з Hive під [key].
Future<Fetched<T>> fetchWithCache<T>(
  Ref ref, {
  required String key,
  required Future<T> Function() fetch,
  required Object Function(T value) toJson,
  required T Function(Object json) fromJson,
}) async {
  final cache = ref.read(jsonCacheProvider);
  try {
    final value = await fetch();
    await cache.write(key, {'value': toJson(value)}, DateTime.now());
    return Fetched(value);
  } catch (error) {
    final cached = cache.read(key);
    if (cached == null) rethrow;
    try {
      return Fetched(fromJson(cached.data['value'] as Object), savedAt: cached.savedAt, staleError: error);
    } catch (_) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }
}

/// Account ID того, хто увійшов, або `null` для гостя.
final accountIdProvider = Provider<int?>((ref) => ref.watch(authControllerProvider).session?.accountId);

final playerProfileProvider = FutureProvider.autoDispose<Fetched<PlayerProfile>>((ref) async {
  final accountId = ref.watch(accountIdProvider);
  if (accountId == null) throw StateError('not signed in');
  return fetchWithCache(
    ref,
    key: 'profile:$accountId',
    fetch: () => ref.read(profileRepositoryProvider).fetchProfile(accountId),
    toJson: (p) => p.toJson(),
    fromJson: (json) => PlayerProfile.fromJson(json as Map<String, dynamic>),
  );
});

class ProfilePeriodController extends Notifier<ProfilePeriod> {
  @override
  ProfilePeriod build() => ProfilePeriod.last25;

  void select(ProfilePeriod period) => state = period;
}

final profilePeriodProvider = NotifierProvider<ProfilePeriodController, ProfilePeriod>(ProfilePeriodController.new);

final playerMatchesProvider = FutureProvider.autoDispose.family<Fetched<List<PlayerMatch>>, ProfilePeriod>((ref, period) async {
  final accountId = ref.watch(accountIdProvider);
  if (accountId == null) throw StateError('not signed in');
  return fetchWithCache(
    ref,
    key: 'matches:$accountId:${period.name}',
    fetch: () => ref.read(profileRepositoryProvider).fetchMatches(accountId, period),
    toJson: (matches) => [for (final m in matches) m.toJson()],
    fromJson: (json) => [for (final m in json as List) PlayerMatch.fromOpenDota(m as Map<String, dynamic>)],
  );
});
