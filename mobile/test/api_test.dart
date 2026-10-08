import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dota_builds/core/network/api_client.dart';
import 'package:dota_builds/features/auth/application/auth_controller.dart';
import 'package:dota_builds/features/auth/data/api_auth_repository.dart';
import 'package:dota_builds/features/auth/data/auth_repository.dart';
import 'package:dota_builds/features/auth/domain/auth_session.dart';
import 'package:dota_builds/features/hero/data/api_hero_repository.dart';
import 'package:dota_builds/features/hero/domain/hero_details.dart';
import 'package:dota_builds/features/meta/data/api_meta_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('ApiAuthRepository', () {
    final ok = {
      'token': 'jwt-123',
      'user': {'id': 'usr_1', 'email': 'player@example.com'},
    };

    Future<AuthFailure> failureOf(Future<AuthSession> call) async {
      try {
        await call;
      } on AuthException catch (e) {
        return e.failure;
      }
      fail('очікували AuthException');
    }

    test('вхід: 200 → сесія, 401 → невірні дані', () async {
      final adapter = FakeAdapter((r) {
        final body = r.data as Map;
        return body['password'] == 'secret123' ? (200, ok) : (401, {'error': 'invalid_credentials'});
      });
      final repo = ApiAuthRepository(dioWith(adapter));

      final session = await repo.login(email: 'player@example.com', password: 'secret123');
      expect(session.token, 'jwt-123');
      expect(adapter.requests.single.path, '/api/auth/login');
      expect(await failureOf(repo.login(email: 'player@example.com', password: 'nope')), AuthFailure.invalidCredentials);
    });

    test('реєстрація: 201 → сесія, 400 → email зайнятий, 400 invalid_data → невалідні дані', () async {
      var reply = (201, ok as Object?);
      final repo = ApiAuthRepository(dioWith(FakeAdapter((_) => reply)));

      expect((await repo.register(email: 'new@example.com', password: 'secret123')).user.id, 'usr_1');

      reply = (400, {'error': 'email_taken'});
      expect(await failureOf(repo.register(email: 'a@b.co', password: 'secret123')), AuthFailure.emailTaken);

      reply = (400, null);
      expect(await failureOf(repo.register(email: 'a@b.co', password: 'secret123')), AuthFailure.emailTaken);

      reply = (400, {'error': 'invalid_data'});
      expect(await failureOf(repo.register(email: 'a@b.co', password: 'secret123')), AuthFailure.invalidData);
    });

    test('немає мережі → network, 5xx → server', () async {
      final offline = ApiAuthRepository(dioWith(FakeAdapter((_) => null)));
      expect(await failureOf(offline.login(email: 'a@b.co', password: 'x')), AuthFailure.network);

      final down = ApiAuthRepository(dioWith(FakeAdapter((_) => (502, null))));
      expect(await failureOf(down.login(email: 'a@b.co', password: 'x')), AuthFailure.server);
    });
  });

  group('токен', () {
    late FakeAdapter adapter;
    late ProviderContainer container;

    setUp(() async {
      adapter = FakeAdapter((r) => r.path == '/admin/sync' ? (401, null) : (200, {'status': 'ok'}));
      container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository(latency: Duration.zero)),
      ]);
      container.read(dioProvider).httpClientAdapter = adapter;
      await container.read(authControllerProvider.notifier).signIn(
            email: MockAuthRepository.demoEmail,
            password: MockAuthRepository.demoPassword,
          );
    });

    tearDown(() => container.dispose());

    test('йде лише в захищені запити', () async {
      final dio = container.read(dioProvider);
      await dio.get<Object>('/api/meta/dota');
      await dio.get<Object>('/api/health', options: authorized());

      expect(adapter.requests[0].headers['Authorization'], isNull);
      expect(adapter.requests[1].headers['Authorization'], startsWith('Bearer mock-token-'));
    });

    test('401 на захищеному запиті закриває сесію', () async {
      final dio = container.read(dioProvider);
      await expectLater(dio.post<Object>('/admin/sync', options: authorized()), throwsA(isA<DioException>()));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
    });
  });
}
