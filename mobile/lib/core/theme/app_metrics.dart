import 'package:flutter/material.dart';

/// Відступи, радіуси, розміри й тривалості анімацій (специфікація, «Тема у Flutter»).
///
/// Живе в [ThemeData.extensions], тож віджети читають ці значення через
/// `context.metrics`, а не з власних констант.
@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics({
    this.space1 = 4,
    this.space2 = 8,
    this.space3 = 12,
    this.space4 = 16,
    this.space6 = 24,
    this.space8 = 32,
    this.radiusSm = 6,
    this.radiusMd = 10,
    this.radiusLg = 12,
    this.radiusXl = 16,
    this.hitTarget = 48,
    this.thumb = 48,
    this.iconSize = 24,
    this.iconSizeSm = 20,
    this.motionFast = const Duration(milliseconds: 120),
    this.motionBase = const Duration(milliseconds: 200),
    this.motionSlow = const Duration(milliseconds: 320),
  });

  final double space1;
  final double space2;
  final double space3;

  /// Бічні поля екрана.
  final double space4;
  final double space6;

  /// Між секціями.
  final double space8;

  /// Теги.
  final double radiusSm;

  /// Мініатюри, стадії предметів.
  final double radiusMd;

  /// Пошук, банер, тост, кнопки.
  final double radiusLg;

  /// Картки, плитки, списки.
  final double radiusXl;

  /// Мінімальна зона натискання на Android.
  final double hitTarget;
  final double thumb;
  final double iconSize;
  final double iconSizeSm;

  final Duration motionFast;
  final Duration motionBase;
  final Duration motionSlow;

  EdgeInsets get screenPadding => EdgeInsets.symmetric(horizontal: space4);

  @override
  AppMetrics copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space6,
    double? space8,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? hitTarget,
    double? thumb,
    double? iconSize,
    double? iconSizeSm,
    Duration? motionFast,
    Duration? motionBase,
    Duration? motionSlow,
  }) {
    return AppMetrics(
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space6: space6 ?? this.space6,
      space8: space8 ?? this.space8,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      hitTarget: hitTarget ?? this.hitTarget,
      thumb: thumb ?? this.thumb,
      iconSize: iconSize ?? this.iconSize,
      iconSizeSm: iconSizeSm ?? this.iconSizeSm,
      motionFast: motionFast ?? this.motionFast,
      motionBase: motionBase ?? this.motionBase,
      motionSlow: motionSlow ?? this.motionSlow,
    );
  }

  /// Метрики не інтерполюються: тема одна, перемикання між варіантами миттєве.
  @override
  AppMetrics lerp(ThemeExtension<AppMetrics>? other, double t) {
    if (other is! AppMetrics) return this;
    return t < 0.5 ? this : other;
  }
}
