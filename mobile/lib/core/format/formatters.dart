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

  static const _monthsGen = ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня', 'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня'];

  /// Тиждень до [end]: «2–8 жовтня» або «28 вересня – 4 жовтня».
  static String weekRange(DateTime end) {
    final to = end.toLocal();
    final from = to.subtract(const Duration(days: 6));
    if (from.month == to.month) return '${from.day}–${to.day} ${_monthsGen[to.month - 1]}';
    return '${from.day} ${_monthsGen[from.month - 1]} – ${to.day} ${_monthsGen[to.month - 1]}';
  }

  /// 3 978 299 → «4,0 млн матчів», 12 400 → «12,4 тис. матчів», 7 → «7 матчів».
  static String matches(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} млн матчів';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} тис. матчів';
    return '$n ${plural(n, one: 'матч', few: 'матчі', many: 'матчів')}';
  }

  static String games(int n) => '$n ${plural(n, one: 'гра', few: 'гри', many: 'ігор')}';

  /// +1,8 · −0,9 · 0,0 (процентні пункти).
  static String delta(double value) {
    final text = value.abs().toStringAsFixed(1).replaceAll('.', ',');
    return value > 0.05 ? '+$text' : value < -0.05 ? '−$text' : text;
  }

  /// 575 с → «9:35».
  static String clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// «2 год тому», «вчора», «5 дн тому», «24 вер».
  static String ago(DateTime time, DateTime now) {
    final diff = now.difference(time.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} хв тому';
    if (diff.inHours < 24) return '${diff.inHours} год тому';
    if (diff.inDays == 1) return 'вчора';
    if (diff.inDays < 7) return '${diff.inDays} дн тому';
    final local = time.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }
}
