import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:backend/db/app_database.dart';
import 'package:backend/db/database_files.dart';
import 'package:backend/sync/hero_sync.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response _json(Object body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

String _readSeed(String name) => findDatabaseFile('seeds/$name').readAsStringSync();

// The DB has no patch column yet, so the patch comes from meta.json.
// Top-level finals are lazy: the file is read on first access, then cached.
final String _seedPatch = (jsonDecode(_readSeed('meta.json')) as Map<String, dynamic>)['patch'] as String;

Map<String, dynamic>? _seedHero(int id) {
  final heroes = (jsonDecode(_readSeed('dota2.json')) as Map<String, dynamic>)['heroes'] as List;
  return heroes.cast<Map<String, dynamic>>().where((h) => h['id'] == id).firstOrNull;
}

Router buildRouter(AppDatabase db, HeroSync sync) {
  final router = Router(
    notFoundHandler: (Request req) => _json({'error': 'not_found'}, status: 404),
  );

  router.get('/api/health', (Request req) => _json({
        'status': 'ok',
        'time': DateTime.now().toUtc().toIso8601String(),
      }));

  router.get('/api/meta/dota', (Request req) {
    try {
      final heroes = db.metaHeroes();
      if (heroes.isNotEmpty) {
        return _json({'updated_at': db.lastUpdated(), 'patch': _seedPatch, 'meta_heroes': heroes});
      }
    } catch (e) {
      print('meta: DB read failed, serving seed: $e');
    }
    return Response.ok(_readSeed('meta.json'), headers: _jsonHeaders);
  });

  // <id|[0-9]+> only matches digits, so /heroes/abc falls through to 404.
  router.get('/api/dota/heroes/<id|[0-9]+>', (Request req, String id) {
    final heroId = int.tryParse(id);
    if (heroId == null) return _json({'error': 'hero_not_found'}, status: 404);

    Map<String, Object?>? hero;
    try {
      hero = db.heroWithBuild(heroId);
    } catch (e) {
      print('hero $heroId: DB read failed, serving seed: $e');
      hero = _seedHero(heroId);
    }
    if (hero == null) return _json({'error': 'hero_not_found'}, status: 404);
    return _json(hero);
  });

  // Manual sync for the demo. No token yet: auth comes last in the plan.
  router.post('/admin/sync', (Request req) async {
    try {
      final result = await sync.run();
      return _json({
        'status': 'ok',
        'synced_at': result.syncedAt.toIso8601String(),
        'heroes_updated': result.heroesUpdated,
      });
    } catch (e) {
      print('admin sync failed: $e');
      return _json({'status': 'error', 'error': e.toString()}, status: 502);
    }
  });

  return router;
}
