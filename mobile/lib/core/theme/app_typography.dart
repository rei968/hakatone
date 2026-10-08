import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Шрифтові ролі [TextTheme] (специфікація, «Типографіка → TextTheme»).
///
/// Кольори тут не задаються: їх проставляє [AppTheme] через `TextTheme.apply`,
/// а текст другого плану фарбується на місці через `context.colors.textMuted`.
abstract final class AppTypography {
  static const display = 'Unbounded';
  static const body = 'Onest';
  static const mono = 'JetBrains Mono';

  static TextTheme textTheme() {
    return TextTheme(
      headlineMedium: _style(display, 26, 32, FontWeight.w600, tracking: -0.02),
      headlineSmall: _style(display, 22, 28, FontWeight.w600, tracking: -0.01),
      titleLarge: _style(display, 17, 22, FontWeight.w600, tracking: -0.01),
      titleMedium: _style(body, 17, 22, FontWeight.w600),
      titleSmall: _style(display, 15, 20, FontWeight.w600, tracking: -0.01),
      bodyLarge: _style(body, 15, 20, FontWeight.w400),
      bodyMedium: _style(body, 13, 18, FontWeight.w400),
      bodySmall: _style(body, 12, 16, FontWeight.w400),
      labelLarge: _style(body, 14, 20, FontWeight.w600),
      labelMedium: _style(body, 12, 16, FontWeight.w500),
      labelSmall: _style(mono, 11, 18, FontWeight.w600),
    );
  }

  /// [tracking] — частка від розміру шрифту (−0.01 = −1 %).
  static TextStyle _style(
    String family,
    double size,
    double lineHeight,
    FontWeight weight, {
    double tracking = 0,
  }) {
    final style = TextStyle(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: size * tracking,
      fontFeatures: family == mono ? const [FontFeature.tabularFigures()] : null,
    );
    try {
      return GoogleFonts.getFont(family, textStyle: style);
    } on Exception {
      // Шрифту немає в цій версії google_fonts — лишаємо системний,
      // щоб застосунок запустився. Перед APK шрифти вбудовуються (див. TODO.md, «Перед збіркою APK»).
      return style;
    }
  }
}
