import 'package:dota_builds/core/format/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('відсотки з комою', () {
    expect(Fmt.percent(53.4), '53,4%');
    expect(Fmt.percent(50), '50,0%');
  });

  test('три форми множини', () {
    expect(Fmt.heroes(1), '1 герой');
    expect(Fmt.heroes(3), '3 герої');
    expect(Fmt.heroes(5), '5 героїв');
    expect(Fmt.heroes(11), '11 героїв');
    expect(Fmt.heroes(12), '12 героїв');
    expect(Fmt.heroes(21), '21 герой');
    expect(Fmt.heroes(22), '22 герої');
    expect(Fmt.heroes(124), '124 герої');
  });

  group('updatedAgo', () {
    final now = DateTime(2026, 10, 8, 12, 30);
    test('до хвилини', () => expect(Fmt.updatedAgo(now.subtract(const Duration(seconds: 20)), now), 'щойно оновлено'));
    test('хвилини', () => expect(Fmt.updatedAgo(now.subtract(const Duration(minutes: 12)), now), 'оновлено 12 хв тому'));
    test('години', () => expect(Fmt.updatedAgo(now.subtract(const Duration(hours: 3)), now), 'оновлено 3 год тому'));
    test('вчора', () => expect(Fmt.updatedAgo(DateTime(2026, 10, 7, 23), now), 'оновлено вчора'));
    test('давно', () => expect(Fmt.updatedAgo(DateTime(2026, 9, 24, 10), now), 'оновлено 24 вер'));
  });
}
