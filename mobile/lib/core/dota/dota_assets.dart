import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Картинки Dota 2 лежать на CDN Steam; довідники зберігають лише шлях.
const steamCdn = 'https://cdn.cloudflare.steamstatic.com';

/// Звідки читати assets. У тестах підміняється синхронним читанням з диска.
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

@immutable
class DotaHeroInfo {
  const DotaHeroInfo({required this.id, required this.name, required this.attribute, this.imagePath, this.abilities = const []});

  final int id;
  final String name;

  /// `str`, `agi`, `int`, `all` — як `primary_attr` у API.
  final String attribute;
  final String? imagePath;

  /// Здібності героя в порядку слотів: (назва, шлях до іконки).
  final List<(String, String)> abilities;

  String? get imageUrl => imagePath == null ? null : '$steamCdn$imagePath';
}

/// Довідники «назва → іконка» з констант OpenDota (`assets/data`,
/// генерує `tool/generate_dota_assets.dart`). Бекенд віддає в білді лише
/// назви предметів і здібностей, а картинки на CDN адресуються ключем.
class DotaAssets {
  DotaAssets({required Map<String, String> items, required Map<String, String> abilities, required this.heroes})
      : _items = items,
        _abilities = abilities;

  static Future<DotaAssets> load(AssetBundle bundle) async {
    Future<Map<String, dynamic>> read(String name) async =>
        jsonDecode(await bundle.loadString('assets/data/$name')) as Map<String, dynamic>;
    final (items, abilities, heroes) =
        await (read('dota_items.json'), read('dota_abilities.json'), read('dota_heroes.json')).wait;
    return DotaAssets(
      items: items.cast<String, String>(),
      abilities: abilities.cast<String, String>(),
      heroes: {
        for (final MapEntry(:key, :value) in heroes.entries)
          int.parse(key): _hero(int.parse(key), value as Map<String, dynamic>),
      },
    );
  }

  static DotaHeroInfo _hero(int id, Map<String, dynamic> json) => DotaHeroInfo(
        id: id,
        name: json['name'] as String,
        attribute: json['attr'] as String? ?? '',
        imagePath: json['img'] as String?,
        abilities: [
          for (final a in json['abilities'] as List? ?? const [])
            ((a as Map)['name'] as String, a['img'] as String),
        ],
      );

  final Map<String, String> _items;
  final Map<String, String> _abilities;
  final Map<int, DotaHeroInfo> heroes;

  /// Скорочення, якими AI й гравці часто називають предмети.
  static const _itemAliases = {
    'bkb': 'black king bar',
    'mkb': 'monkey king bar',
    'blink': 'blink dagger',
    'aghs': "aghanim's scepter",
    'aghanim scepter': "aghanim's scepter",
    'aghanims scepter': "aghanim's scepter",
    'aghanim shard': "aghanim's shard",
    'shard': "aghanim's shard",
    'treads': 'power treads',
    'phase': 'phase boots',
    'midas': 'hand of midas',
    'refresher': 'refresher orb',
    'shivas guard': "shiva's guard",
    'eul': "eul's scepter of divinity",
    "eul's scepter": "eul's scepter of divinity",
    'euls': "eul's scepter of divinity",
    'basher': 'skull basher',
    'abyssal': 'abyssal blade',
    'manta': 'manta style',
    'deso': 'desolator',
    'daedalus': 'daedalus',
    'sny': 'sange and yasha',
    'sange & yasha': 'sange and yasha',
    'kaya & sange': 'kaya and sange',
    'yasha & kaya': 'yasha and kaya',
    'heart': 'heart of tarrasque',
    'bot': 'boots of travel',
    'travels': 'boots of travel',
    'force': 'force staff',
    'glimmer': 'glimmer cape',
    'pipe': 'pipe of insight',
    'lotus': 'lotus orb',
    'linken': "linken's sphere",
    "linken's": "linken's sphere",
    'linkens sphere': "linken's sphere",
    'radiance': 'radiance',
    'ac': 'assault cuirass',
  };

  /// Ключ пошуку: той самий, що й у генераторі.
  static String normalize(String name) =>
      name.toLowerCase().replaceAll(RegExp('[’ʼ`]'), "'").replaceAll(RegExp(r'\s+'), ' ').trim();

  String? itemIcon(String name) {
    final key = normalize(name);
    final path = _items[key] ?? _items[_itemAliases[key] ?? ''] ?? _items[key.replaceAll("'", '')];
    return path == null ? null : '$steamCdn$path';
  }

  /// Спершу серед здібностей самого героя: однакові назви трапляються в різних героїв.
  String? abilityIcon(String name, {int? heroId}) {
    final key = normalize(name);
    for (final (abilityName, path) in heroes[heroId]?.abilities ?? const <(String, String)>[]) {
      if (normalize(abilityName) == key) return '$steamCdn$path';
    }
    final path = _abilities[key];
    return path == null ? null : '$steamCdn$path';
  }

  DotaHeroInfo? hero(int id) => heroes[id];
}

/// Довідники вантажаться один раз. Поки їх немає, іконки показують монограми.
final dotaAssetsProvider = FutureProvider<DotaAssets>((ref) => DotaAssets.load(ref.watch(assetBundleProvider)));
