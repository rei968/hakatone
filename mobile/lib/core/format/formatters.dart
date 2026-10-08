/// Українські формати для інтерфейсу (специфікація головного меню, «Контент»).
abstract final class Fmt {
  /// 53.4 → «53,4%».
  static String percent(double value) => '${value.toStringAsFixed(1).replaceAll('.', ',')}%';

  /// Три форми множини: 1 герой, 3 герої, 12 героїв, 21 герой.
  static String plural(int n, {required String one, required String few, required String many}) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  static String heroes(int n) => '$n ${plural(n, one: 'герой', few: 'герої', many: 'героїв')}';

  static const _months = ['січ', 'лют', 'бер', 'кві', 'тра', 'чер', 'лип', 'сер', 'вер', 'жов', 'лис', 'гру'];

  /// «щойно оновлено», «оновлено 12 хв тому», «оновлено 3 год тому»,
  /// «оновлено вчора», «оновлено 24 вер». [updatedAt] може бути в UTC.
  static String updatedAgo(DateTime updatedAt, DateTime now) {
    final local = updatedAt.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'щойно оновлено';
    if (diff.inMinutes < 60) return 'оновлено ${diff.inMinutes} хв тому';
    if (diff.inHours < 24 && local.day == now.day) return 'оновлено ${diff.inHours} год тому';
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (!local.isBefore(yesterday)) return 'оновлено вчора';
    return 'оновлено ${local.day} ${_months[local.month - 1]}';
  }

  /// «8 жов, 09:12» — коли були збережені дані, які показуємо офлайн.
  static String dateTime(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]}, $hh:$mm';
  }
}
