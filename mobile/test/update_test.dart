import 'package:dota_builds/core/storage/app_storage.dart';
import 'package:dota_builds/features/update/application/update_controller.dart';
import 'package:dota_builds/features/update/data/update_repository.dart';
import 'package:dota_builds/features/update/domain/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> githubRelease({
  String tag = 'v0.2.0',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>>? assets,
}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'body': 'Нова картка героя',
      'assets': assets ??
          [
            {'name': 'notes.txt', 'browser_download_url': 'https://github.com/x/notes.txt'},
            {
              'name': 'MangoDota-0.2.0.apk',
              'browser_download_url': 'https://github.com/rei968/hakatone/releases/download/v0.2.0/MangoDota-0.2.0.apk',
              'digest': 'sha256:abc123',
            },
          ],
    };

class FakeUpdateRepository implements UpdateRepository {
  FakeUpdateRepository(this.release, {this.fail = false});

  AppRelease? release;
  bool fail;
  int calls = 0;

  @override
  Future<AppRelease?> latestRelease() async {
    calls++;
    if (fail) throw Exception('немає мережі');
    return release;
  }
}

void main() {
  group('версії', () {
    test('розбір тегу', () {
      expect(parseVersion('v0.2.0'), [0, 2, 0]);
      expect(parseVersion('1.10.3+42'), [1, 10, 3]);
      expect(parseVersion('2.0.0-beta'), [2, 0, 0]);
      expect(parseVersion('release-1'), isNull);
      expect(parseVersion('1.2'), isNull);
    });

    test('порівняння числами, а не рядками', () {
      expect(isNewerVersion('0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('0.10.0', '0.9.9'), isTrue);
      expect(isNewerVersion('1.0.0', '0.99.99'), isTrue);
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.2.0'), isFalse);
      expect(isNewerVersion('щось', '0.1.0'), isFalse);
    });
  });

  group('реліз з GitHub', () {
    test('бере версію, APK і контрольну суму', () {
      final release = AppRelease.fromGitHub(githubRelease())!;
      expect(release.version, '0.2.0');
      expect(release.apkUrl, endsWith('MangoDota-0.2.0.apk'));
      expect(release.sha256, 'abc123');
      expect(release.notes, 'Нова картка героя');
    });

    test('чернетки, пре-релізи, реліз без APK і дивний тег пропускаються', () {
      expect(AppRelease.fromGitHub(githubRelease(draft: true)), isNull);
      expect(AppRelease.fromGitHub(githubRelease(prerelease: true)), isNull);
      expect(AppRelease.fromGitHub(githubRelease(assets: [])), isNull);
      expect(AppRelease.fromGitHub(githubRelease(tag: 'latest')), isNull);
      expect(
        AppRelease.fromGitHub(githubRelease(assets: [
          {'name': 'app.apk', 'browser_download_url': 'http://insecure.example/app.apk'},
        ])),
        isNull,
      );
    });
  });

  group('UpdateChecker', () {
    late MemoryKeyValueStore store;
    late FakeUpdateRepository repository;
    var now = DateTime.utc(2026, 10, 8, 12);

    UpdateChecker checker({bool enabled = true, String current = '0.1.0'}) => UpdateChecker(
          repository: repository,
          store: store,
          currentVersion: () async => current,
          enabled: enabled,
          clock: () => now,
        );

    setUp(() {
      store = MemoryKeyValueStore();
      repository = FakeUpdateRepository(AppRelease.fromGitHub(githubRelease()));
      now = DateTime.utc(2026, 10, 8, 12);
    });

    test('знаходить новішу версію', () async {
      final update = await checker().check();
      expect(update?.release.version, '0.2.0');
      expect(update?.currentVersion, '0.1.0');
    });

    test('та сама версія — оновлень немає', () async {
      expect(await checker(current: '0.2.0').check(), isNull);
    });

    test('вимкнено (debug, web, не Android) — GitHub не питаємо', () async {
      expect(await checker(enabled: false).check(), isNull);
      expect(repository.calls, 0);
    });

    test('не частіше разу на добу', () async {
      final c = checker();
      await c.check();
      now = now.add(const Duration(hours: 23));
      expect(await c.check(), isNull);
      expect(repository.calls, 1);

      now = now.add(const Duration(hours: 1));
      expect(await c.check(), isNotNull);
      expect(repository.calls, 2);
    });

    test('force перевіряє одразу', () async {
      final c = checker();
      await c.check();
      expect(await c.check(force: true), isNotNull);
      expect(repository.calls, 2);
    });

    test('помилка мережі — тихо нічого, наступна спроба завтра', () async {
      repository.fail = true;
      final c = checker();
      expect(await c.check(), isNull);
      expect(store.read(UpdateChecker.lastCheckKey), isNotNull);
    });
  });
}
