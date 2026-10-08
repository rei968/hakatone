import 'package:flutter/painting.dart';

/// Сирі значення колірних токенів MangoDota
/// (docs/design/01-main-menu.html, §01 «Палітра розхідників»).
///
/// Акценти взято з розхідників Dota 2, у кожного одна роль.
/// Імпортують лише файли теми; віджети беруть кольори з `Theme.of(context)`.
abstract final class AppPalette {
  // Нейтральні.
  static const bg = Color(0xFF10141B);
  static const surface1 = Color(0xFF171C25);
  static const surface2 = Color(0xFF1F2531);
  static const surface3 = Color(0xFF283040);
  static const border = Color(0xFF2A3141);
  static const text = Color(0xFFE9ECF2);
  static const textMuted = Color(0xFF9AA3B5);
  static const textSubtle = Color(0xFF7C8599);

  /// Текст на заливці манго й на бейджах тірів.
  static const ink = Color(0xFF1A1206);

  // Розхідники.
  /// Enchanted Mango — бренд, головні дії, S-тір.
  static const mango = Color(0xFFFFA62B);
  static const mangoSoft = Color(0x24FFA62B); // 14 %

  /// Tango — добре: високий вінрейт, свіжі дані, A-тір.
  static const tango = Color(0xFF7BC74D);

  /// Healing Salve — погано: низький вінрейт, помилки, C-тір.
  static const salve = Color(0xFFF2545B);

  /// Clarity — інформація: посилання, фокус, офлайн, B-тір.
  static const clarity = Color(0xFF4DA3FF);

  /// Smoke of Deceit — усе, що згенерував AI.
  static const smoke = Color(0xFFA27BFF);
  static const smokeSoft = Color(0x1FA27BFF); // 12 %

  /// Dust of Appearance — відблиск скелетона, «Щойно оновлено».
  static const dust = Color(0xFFE9D8A6);
}
