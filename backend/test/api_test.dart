import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:backend/api/router.dart';
import 'package:backend/auth/auth_service.dart';
import 'package:backend/auth/jwt_service.dart';
import 'package:backend/auth/password_hasher.dart';
import 'package:backend/db/app_database.dart';
import 'package:backend/opendota/opendota_client.dart';
import 'package:backend/sync/hero_sync.dart';

// Run from backend/ (`dart test`), so database/schema.sql and seeds are found.
void main() {
  late AppDatabase db;
  late Handler handler;

  setUp(() {
    db = AppDatabase.open(':memory:');
    final openDota = OpenDotaClient(baseUrl: 'http://127.0.0.1:1/api'); // never called here
    final auth = AuthService(db, JwtService('test-secret'), PasswordHasher(iterations: 10));
    handler = buildRouter(db, HeroSync(db, openDota), null, auth).call;
  });

  Future<(int, Map<String, dynamic>)> get(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()) as Map<String, dynamic>);
  }

  group('?rank=', () {
    test('unknown rank is 400 invalid_rank on both endpoints', () async {
      for (final path in ['/api/meta/dota?rank=immortal', '/api/dota/heroes/14?rank=pro']) {
        final (status, body) = await get(path);
        expect(status, 400, reason: path);
        expect(body, {'error': 'invalid_rank'});
      }
    });

    test('meta reports the rank and the sample size', () async {
      final (status, body) = await get('/api/meta/dota?rank=divine');
      expect(status, 200);
      expect(body['rank'], 'divine');
      expect(body['total_matches'], isA<int>());
      expect((body['meta_heroes'] as List).first, contains('win_rate_delta'));
    });

    test('without the parameter the rank is all', () async {
      final (_, body) = await get('/api/meta/dota');
      expect(body['rank'], 'all');
      expect(body['patch'], isNotEmpty);
    });

    test('per-rank numbers come from rank_stats', () async {
      db.upsertHeroes([
        for (final (id, pick, win) in [(14, 600, 330), (8, 300, 141), (74, 100, 49)])
          {
            'id': id,
            'name': 'Hero $id',
            'win_rate': 50.0,
            'pick_rate': 10.0,
            'tier': 'A',
            'matches': 1000,
            'win_rate_delta': -1.5,
            'rank_stats': {
              '7': {'pick': pick, 'win': win},
            },
          },
      ]);
      final (_, body) = await get('/api/meta/dota?rank=divine');
      final heroes = body['meta_heroes'] as List;
      expect(body['total_matches'], 100);
      expect(heroes.first, containsPair('id', 14));
      expect(heroes.first, containsPair('win_rate', 55.0));
      expect(heroes.first, containsPair('matches', 600));
      expect(heroes.first, containsPair('tier', 'S'));
      expect(heroes.first, containsPair('win_rate_delta', -1.5));

      final (_, hero) = await get('/api/dota/heroes/8?rank=divine');
      expect(hero['win_rate'], 47.0);
      expect(hero['matches'], 300);
    });
  });

  test('an old DB file gets the new columns', () {
    final dir = Directory.systemTemp.createTempSync('mangodota_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/old.db';
    sqlite3.open(path)
      ..execute('CREATE TABLE heroes (id INTEGER PRIMARY KEY, name TEXT NOT NULL, win_rate REAL, '
          'pick_rate REAL, tier TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)')
      ..execute('CREATE TABLE ai_builds (id INTEGER PRIMARY KEY AUTOINCREMENT, hero_id INTEGER UNIQUE NOT NULL, '
          'skill_order TEXT, core_items TEXT, tactics TEXT, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP)')
      ..execute("INSERT INTO heroes (id, name) VALUES (1, 'Anti-Mage')")
      ..close();

    AppDatabase.open(path).close();

    final check = sqlite3.open(path);
    addTearDown(check.close);
    Set<String> columns(String table) => {for (final r in check.select('PRAGMA table_info($table)')) r['name'] as String};
    expect(columns('heroes'), containsAll(['matches', 'win_rate_delta', 'rank_stats']));
    expect(columns('ai_builds'), containsAll(['talents', 'item_timings', 'situational_items']));
  });
}
