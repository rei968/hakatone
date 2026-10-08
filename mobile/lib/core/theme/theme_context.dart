import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_metrics.dart';

/// Короткий доступ до теми з віджетів: `context.colors.textMuted`,
/// `context.metrics.space4`, `context.text.titleLarge`.
extension ThemeContextX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppMetrics get metrics => Theme.of(this).extension<AppMetrics>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
