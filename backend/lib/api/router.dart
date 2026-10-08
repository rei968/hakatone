import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:backend/ai/hero_analyzer.dart';
import 'package:backend/auth/auth_service.dart';
import 'package:backend/db/app_database.dart';
import 'package:backend/db/database_files.dart';
import 'package:backend/meta/hero_stats.dart';
import 'package:backend/sync/hero_sync.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response _json(Object body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

String _readSeed(String name) => findDatabaseFile('seeds/$name').readAsStringSync();

// Fallback until the first sync saves the real patch from OpenDota.
// Top-level finals are lazy: the file is read on first access, then cached.
final String _seedPatch = (jsonDecode(_readSeed('meta.json')) as Map<String, dynamic>)['patch'] as String;

Map<String, dynamic>? _seedHero(int id) {
  final heroes = (jsonDecode(_readSeed('dota2.json')) as Map<String, dynamic>)['heroes'] as List;
  return heroes.cast<Map<String, dynamic>>().where((h) => h['id'] == id).firstOrNull;
}

/// How long a hero request waits for a fresh AI analysis. A slower one still finishes
/// in the background and is cached for the next request.
const _aiTimeout = Duration(seconds: 25);

/// Parses `{email, password}` and runs [action]; an [AuthError] becomes `{"error": code}`.
Future<Response> _authCall(
  Request req,
  Map<String, Object?> Function(String email, String password) action, {
  int status = 200,
}) async {
  final Object? body;
  try {
    body = jsonDecode(await req.readAsString());
  } on FormatException {
    return _json({'error': 'invalid_body'}, status: 400);
  }
  if (body is! Map || body['email'] is! String || body['password'] is! String) {
    return _json({'error': 'invalid_body'}, status: 400);
  }

  try {
    return _json(action(body['email'] as String, body['password'] as String), status: status);
  } on AuthError catch (e) {
    return _json({'error': e.code}, status: e.status);
  }
}

/// [analyzer] is null when no AI key is configured: heroes are then served without new builds.
Router buildRouter(AppDatabase db, HeroSync sync, HeroAnalyzer? analyzer, AuthService auth) {
  final router = Router(
    notFoundHandler: (Request req) => _json({'error': 'not_found'}, status: 404),
  );

  router.get('/api/health', (Request req) => _json({
        'status': 'ok',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }));

  router.get('/api/meta/dota', (Request req) {
    final int? bracket;
    try {
      bracket = parseRank(req.url.queryParameters['rank']);
    } on InvalidRankException {
      return _json({'error': 'invalid_rank'}, status: 400);
    }

    try {
      final meta = db.metaHeroes(bracket: bracket);
      if (meta.heroes.isNotEmpty) {
        return _json({
          'updated_at': db.lastUpdated(),
          'patch': db.patch() ?? _seedPatch,
          'rank': rankName(bracket),
          'total_matches': meta.totalMatches,
          'meta_heroes': meta.heroes,
        });
      }
    } catch (e) {
      print('meta: DB read failed, serving seed: $e');
    }
    return Response.ok(_readSeed('meta.json'), headers: _jsonHeaders);
  });

  // <id|[0-9]+> only matches digits, so /heroes/abc falls through to 404.
  router.get('/api/dota/heroes/<id|[0-9]+>', (Request req, String id) async {
    final heroId = int.tryParse(id);
    if (heroId == null) return _json({'error': 'hero_not_found'}, status: 404);
    final int? bracket;
    try {
      bracket = parseRank(req.url.queryParameters['rank']);
    } on InvalidRankException {
      return _json({'error': 'invalid_rank'}, status: 400);
    }

    Map<String, Object?>? hero;
    try {
      hero = db.heroWithBuild(heroId, bracket: bracket);
      // No build yet, or a v1 build without talents: generate it now and store it in ai_builds.
      // Until the new one is ready (or if it fails) the old build is served.
      final build = hero?['ai_build'] as Map<String, Object?>?;
      if (hero != null && (build == null || build['talents'] == null) && analyzer != null) {
        try {
          await analyzer.analyze(heroId).timeout(_aiTimeout);
          hero = db.heroWithBuild(heroId, bracket: bracket);
        } catch (e) {
          print('hero $heroId: AI analysis failed, serving the previous build: $e');
        }
      }
    } catch (e) {
      print('hero $heroId: DB read failed, serving seed: $e');
      hero = _seedHero(heroId);
    }
    if (hero == null) return _json({'error': 'hero_not_found'}, status: 404);
    return _json(hero);
  });

  router.post('/api/auth/register', (Request req) => _authCall(req, auth.register, status: 201));
  router.post('/api/auth/login', (Request req) => _authCall(req, auth.login));

  // Manual sync for the demo; needs the JWT from /api/auth/login (docs/test_endpoints.ps1).
  router.post('/admin/sync', (Request req) async {
    if (auth.userIdFromHeader(req.headers['authorization']) == null) {
      return _json({'error': 'unauthorized'}, status: 401);
    }
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
