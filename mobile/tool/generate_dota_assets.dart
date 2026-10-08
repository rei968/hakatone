// Будує компактні довідники «назва → іконка» з констант OpenDota.
// Запуск з mobile/:  dart run tool/generate_dota_assets.dart
//
// Бекенд у ai_build віддає лише назви («Aghanim's Scepter», «Wraithfire Blast»),
// а картинка на Steam CDN адресується ключем (ultimate_scepter). Ці файли
// зводять одне до іншого. Оновлювати після великих патчів, коли з’являються
// нові предмети чи здібності.
import 'dart:convert';
import 'dart:io';

const _api = 'https://api.opendota.com/api/constants';

Future<Map<String, dynamic>> _fetch(String name) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_api/$name'));
    final response = await request.close();
    if (response.statusCode != 200) throw HttpException('$name: HTTP ${response.statusCode}');
    return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

/// Такий самий ключ рахує застосунок (lib/core/dota/dota_assets.dart).
String normalize(String name) =>
    name.toLowerCase().replaceAll(RegExp('[’ʼ`]'), "'").replaceAll(RegExp(r'\s+'), ' ').trim();

String _path(Object? img) => (img as String? ?? '').split('?').first;

Future<void> main() async {
  final items = <String, String>{};
  (await _fetch('items')).forEach((key, value) {
    final item = value as Map<String, dynamic>;
    final name = item['dname'] as String?;
    final img = _path(item['img']);
    if (name != null && img.isNotEmpty && !key.startsWith('recipe_')) items.putIfAbsent(normalize(name), () => img);
  });

  final abilities = <String, String>{};
  final abilityConstants = await _fetch('abilities');
  abilityConstants.forEach((key, value) {
    final ability = value as Map<String, dynamic>;
    final name = ability['dname'] as String?;
    final img = _path(ability['img']);
    if (name != null && img.isNotEmpty && !key.startsWith('special_bonus')) {
      abilities.putIfAbsent(normalize(name), () => img);
    }
  });

  // Здібності кожного героя в порядку слотів: однакові назви бувають у різних
  // героїв, тож спершу шукаємо серед здібностей самого героя.
  final heroAbilities = await _fetch('hero_abilities');
  final heroes = <String, Map<String, Object>>{};
  (await _fetch('heroes')).forEach((_, value) {
    final hero = value as Map<String, dynamic>;
    // Буває вкладений список: альтернативні здібності в одному слоті.
    final keys = [
      for (final slot in (heroAbilities[hero['name']] as Map<String, dynamic>?)?['abilities'] as List? ?? const [])
        ...(slot is List ? slot : [slot]),
    ].cast<String>().where((key) => key != 'generic_hidden');
    heroes['${hero['id']}'] = {
      'name': hero['localized_name'] as String,
      'attr': hero['primary_attr'] as String,
      'img': _path(hero['img']),
      'abilities': [
        for (final key in keys)
          if (abilityConstants[key] case {'dname': final String name, 'img': final String img})
            {'name': name, 'img': _path(img)},
      ],
    };
  });

  const encoder = JsonEncoder.withIndent(' ');
  final dir = Directory('assets/data')..createSync(recursive: true);
  File('${dir.path}/dota_items.json').writeAsStringSync(encoder.convert(items));
  File('${dir.path}/dota_abilities.json').writeAsStringSync(encoder.convert(abilities));
  File('${dir.path}/dota_heroes.json').writeAsStringSync(encoder.convert(heroes));
  stdout.writeln('items: ${items.length}, abilities: ${abilities.length}, heroes: ${heroes.length}');
}
