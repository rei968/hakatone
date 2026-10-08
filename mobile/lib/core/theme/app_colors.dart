import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Колірні токени поза [ColorScheme]: рівні поверхонь, текст другого плану
/// і палітра розхідників. Семантичні геттери (`success`, `tierS`…) — це
/// псевдоніми розхідників, тож роль кольору задається тут, а не у віджетах.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.textMuted,
    required this.textSubtle,
    required this.ink,
    required this.mango,
    required this.mangoSoft,
    required this.tango,
    required this.salve,
    required this.clarity,
    required this.smoke,
    required this.smokeSoft,
    required this.dust,
  });

  static const dark = AppColors(
    surface1: AppPalette.surface1,
    surface2: AppPalette.surface2,
    surface3: AppPalette.surface3,
    border: AppPalette.border,
    textMuted: AppPalette.textMuted,
    textSubtle: AppPalette.textSubtle,
    ink: AppPalette.ink,
    mango: AppPalette.mango,
    mangoSoft: AppPalette.mangoSoft,
    tango: AppPalette.tango,
    salve: AppPalette.salve,
    clarity: AppPalette.clarity,
    smoke: AppPalette.smoke,
    smokeSoft: AppPalette.smokeSoft,
    dust: AppPalette.dust,
  );

  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;

  /// 6,7 : 1 на surface1 — описи, підписи.
  final Color textMuted;

  /// 4,6 : 1 на surface1 — лише на bg і surface1.
  final Color textSubtle;

  /// Текст на заливці манго й на бейджах тірів.
  final Color ink;

  final Color mango;
  final Color mangoSoft;
  final Color tango;
  final Color salve;
  final Color clarity;
  final Color smoke;
  final Color smokeSoft;
  final Color dust;

  // Ролі.
  Color get success => tango;
  Color get danger => salve;
  Color get info => clarity;
  Color get ai => smoke;

  // Тіри мети.
  Color get tierS => mango;
  Color get tierA => tango;
  Color get tierB => clarity;
  Color get tierC => salve;

  // Атрибути героїв збігаються з розхідниками, як і в самій грі.
  Color get attrStrength => salve;
  Color get attrAgility => tango;
  Color get attrIntelligence => clarity;
  Color get attrUniversal => smoke;

  @override
  AppColors copyWith({
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? textMuted,
    Color? textSubtle,
    Color? ink,
    Color? mango,
    Color? mangoSoft,
    Color? tango,
    Color? salve,
    Color? clarity,
    Color? smoke,
    Color? smokeSoft,
    Color? dust,
  }) {
    return AppColors(
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      ink: ink ?? this.ink,
      mango: mango ?? this.mango,
      mangoSoft: mangoSoft ?? this.mangoSoft,
      tango: tango ?? this.tango,
      salve: salve ?? this.salve,
      clarity: clarity ?? this.clarity,
      smoke: smoke ?? this.smoke,
      smokeSoft: smokeSoft ?? this.smokeSoft,
      dust: dust ?? this.dust,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mango: Color.lerp(mango, other.mango, t)!,
      mangoSoft: Color.lerp(mangoSoft, other.mangoSoft, t)!,
      tango: Color.lerp(tango, other.tango, t)!,
      salve: Color.lerp(salve, other.salve, t)!,
      clarity: Color.lerp(clarity, other.clarity, t)!,
      smoke: Color.lerp(smoke, other.smoke, t)!,
      smokeSoft: Color.lerp(smokeSoft, other.smokeSoft, t)!,
      dust: Color.lerp(dust, other.dust, t)!,
    );
  }
}
