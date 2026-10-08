import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dota_builds/core/network/api_client.dart';
import 'package:dota_builds/core/dota/rank.dart';
import 'package:dota_builds/features/auth/data/steam_openid.dart';
import 'package:dota_builds/features/auth/domain/steam_session.dart';
import 'package:dota_builds/features/profile/data/profile_repository.dart';
import 'package:dota_builds/features/profile/domain/player.dart';
import 'package:dota_builds/features/hero/data/api_hero_repository.dart';
import 'package:dota_builds/features/hero/domain/hero_details.dart';
import 'package:dota_builds/features/meta/data/api_meta_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Відповідає замість сервера. `null` — немає мережі.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final (int, Object?)? Function(RequestOptions request) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(options);
    final reply = respond(options);
    if (reply == null) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    final (status, data) = reply;
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(FakeAdapter adapter) => Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter;

Object seed(String name) => jsonDecode(File('assets/mocks/$name').readAsStringSync()) as Object;

void main() {
  group('ApiMetaRepository', () {
    test('200 → мета з контракту', () async {
      final adapter = FakeAdapter((r) => r.path == '/api/meta/dota' ? (200, seed('meta.json')) : (404, null));
      final report = await ApiMetaRepository(dioWith(adapter)).fetchMeta();
      expect(report.heroes, hasLength(3));
      expect(adapter.requests.single.headers['Authorization'], isNull, reason: 'мета публічна');
    });

    test('500 → server, немає мережі → network', () async {
      final down = ApiMetaRepository(dioWith(FakeAdapter((_) => (500, {'error': 'boom'}))));
      await expectLater(down.fetchMeta(), throwsA(isA<ApiException>().having((e) => e.failure, 'failure', ApiFailure.server)));

      final offline = ApiMetaRepository(dioWith(FakeAdapter((_) => null)));
      await expectLater(offline.fetchMeta(), throwsA(isA<ApiException>().having((e) => e.failure, 'failure', ApiFailure.network)));
    });
  });

  group('ApiHeroRepository', () {
    test('200 → картка, 404 → HeroNotFoundException', () async {
      final heroes = (seed('dota2.json') as Map)['heroes'] as List;
      final adapter = FakeAdapter((r) => switch (r.path) {
            '/api/dota/heroes/14' => (200, heroes.first),
            _ => (404, {'error': 'hero_not_found'}),
          });
      final repo = ApiHeroRepository(dioWith(adapter));

      final pudge = await repo.fetchHero(14);
      expect(pudge.hero.name, 'Pudge');
      expect(pudge.aiBuild?.coreItems, isNotEmpty);
      await expectLater(repo.fetchHero(99999), throwsA(isA<HeroNotFoundException>()));
    });
  });

  test('ранг іде в запит параметром rank, «усі ранги» — без нього', () async {
    final adapter = FakeAdapter((r) => (200, seed('meta.json')));
    final repo = ApiMetaRepository(dioWith(adapter));
    await repo.fetchMeta();
    await repo.fetchMeta(rank: Rank.divine);
    expect(adapter.requests[0].queryParameters, isEmpty);
    expect(adapter.requests[1].queryParameters, {'rank': 'divine'});
  });

  group('Steam', () {
    test('Steam ID з різних форматів', () {
      expect(SteamIds.parse('76561198047011640'), '76561198047011640');
      expect(SteamIds.parse('86745912'), '76561198047011640');
      expect(SteamIds.parse('https://steamcommunity.com/profiles/76561198047011640/'), '76561198047011640');
      expect(SteamIds.parse('https://www.opendota.com/players/86745912'), '76561198047011640');
      expect(SteamIds.parse('https://steamcommunity.com/id/vanity'), isNull);
      expect(SteamIds.parse('abc'), isNull);
      expect(const SteamSession(steamId64: '76561198047011640').accountId, 86745912);
    });

    Uri callback(SteamOpenId openId, {String id = '76561198047011640'}) => Uri.parse(openId.returnTo).replace(queryParameters: {
          'openid.ns': 'http://specs.openid.net/auth/2.0',
          'openid.mode': 'id_res',
          'openid.op_endpoint': SteamOpenId.endpoint,
          'openid.claimed_id': 'https://steamcommunity.com/openid/id/$id',
          'openid.identity': 'https://steamcommunity.com/openid/id/$id',
          'openid.return_to': openId.returnTo,
          'openid.sig': 'sig',
        });

    test('підпис перевіряється в Steam: is_valid:true → Steam ID', () async {
      final adapter = FakeAdapter((r) => (200, 'ns:http://specs.openid.net/auth/2.0\nis_valid:true\n'));
      final openId = SteamOpenId(dioWith(adapter), realm: 'https://hakatone.onrender.com');
      expect(openId.loginUri.queryParameters['openid.return_to'], 'https://hakatone.onrender.com/auth/steam/return');

      expect(await openId.verify(callback(openId)), '76561198047011640');
      final check = adapter.requests.single;
      expect(check.uri.toString(), SteamOpenId.endpoint);
      expect((check.data as Map)['openid.mode'], 'check_authentication');
    });

    test('Steam не підтвердив або гравець скасував — помилка', () async {
      final openId = SteamOpenId(dioWith(FakeAdapter((_) => (200, 'is_valid:false'))), realm: 'https://hakatone.onrender.com');
      await expectLater(openId.verify(callback(openId)), throwsA(isA<SteamLoginException>()));
      final cancelled = Uri.parse(openId.returnTo).replace(queryParameters: {'openid.mode': 'cancel'});
      await expectLater(
        openId.verify(cancelled),
        throwsA(isA<SteamLoginException>().having((e) => e.failure, 'failure', SteamLoginFailure.cancelled)),
      );
    });
  });

  group('OpenDota', () {
    test('профіль, медаль і матчі за період', () async {
      final adapter = FakeAdapter((r) => switch (r.uri.path) {
            '/api/players/86745912' => (200, {
                'profile': {'personaname': 'dima', 'avatarfull': 'https://a/b.jpg'},
                'rank_tier': 73,
              }),
            '/api/players/86745912/wl' => (200, {'win': 2500, 'lose': 2312}),
            '/api/players/86745912/matches' => (200, [
                {'match_id': 1, 'player_slot': 0, 'radiant_win': true, 'hero_id': 42, 'kills': 12, 'deaths': 3, 'assists': 9, 'gold_per_min': 600, 'xp_per_min': 700, 'duration': 2292, 'start_time': 1790000000},
                {'match_id': 2, 'player_slot': 130, 'radiant_win': true, 'hero_id': 8, 'kills': 4, 'deaths': 7, 'assists': 6, 'gold_per_min': 420, 'xp_per_min': 500, 'duration': 2690, 'start_time': 1789990000},
              ]),
            _ => (404, null),
          });
      final repo = OpenDotaProfileRepository(dioWith(adapter));

      final profile = await repo.fetchProfile(86745912);
      expect(profile.name, 'dima');
      expect(profile.medal, 'Divine 3');
      expect(profile.totalMatches, 4812);

      final matches = await repo.fetchMatches(86745912, ProfilePeriod.week);
      final query = adapter.requests.last.uri.query;
      expect(query, contains('date=7'));
      expect(query, contains('project=gold_per_min'));
      expect([for (final m in matches) m.won], [true, false], reason: 'player_slot ≥ 128 — Dire');

      final summary = ProfileSummary.of(matches);
      expect(summary.wins, 1);
      expect(summary.kda, closeTo((8 + 7.5) / 5, 0.01));
      expect(summary.gpm, 510);
      expect(summary.heroPool.first.games, 1);
    });
  });
}
