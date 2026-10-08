import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Мінімальне сховище рядків за ключем. У застосунку це бокс Hive,
/// у тестах — пам’ять.
abstract interface class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemoryKeyValueStore implements KeyValueStore {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class HiveKeyValueStore implements KeyValueStore {
  const HiveKeyValueStore(this._box);

  final Box<String> _box;

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}

/// Два окремі сховища: сесія і кеш відповідей API.
/// Очищення кешу не викидає гравця з акаунта.
class AppStorage {
  const AppStorage({required this.session, required this.cache});

  factory AppStorage.memory() => AppStorage(session: MemoryKeyValueStore(), cache: MemoryKeyValueStore());

  /// Відкриває бокси Hive. Викликається в `main` до `runApp`.
  static Future<AppStorage> openHive() async {
    await Hive.initFlutter('mangodota');
    final session = await Hive.openBox<String>('session');
    final cache = await Hive.openBox<String>('api_cache');
    return AppStorage(session: HiveKeyValueStore(session), cache: HiveKeyValueStore(cache));
  }

  final KeyValueStore session;
  final KeyValueStore cache;
}

/// У застосунку перевизначається відкритими боксами Hive (див. `main`).
final appStorageProvider = Provider<AppStorage>((ref) => AppStorage.memory());

/// Кешований JSON разом із часом збереження.
class JsonCache {
  const JsonCache(this._store);

  final KeyValueStore _store;

  /// `null`, якщо запису немає або він пошкоджений — тоді просто йдемо в мережу.
  ({Map<String, dynamic> data, DateTime savedAt})? read(String key) {
    final raw = _store.read(key);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      return (
        data: entry['data'] as Map<String, dynamic>,
        savedAt: DateTime.parse(entry['saved_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> data, DateTime savedAt) => _store.write(
        key,
        jsonEncode({'saved_at': savedAt.toUtc().toIso8601String(), 'data': data}),
      );
}

final jsonCacheProvider = Provider<JsonCache>((ref) => JsonCache(ref.watch(appStorageProvider).cache));
