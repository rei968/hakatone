import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_metrics.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Єдине джерело кольорів, шрифтів і відступів застосунку.
///
/// Тема одна — темна (рішення зі специфікації головного меню). Нові компоненти
/// стилізуються тут, а не параметрами на місці використання.
abstract final class AppTheme {
  static final ThemeData dark = _buildDark();

  static ThemeData _buildDark() {
    const metrics = AppMetrics();
    final textTheme = AppTypography.textTheme().apply(
      bodyColor: AppPalette.text,
      displayColor: AppPalette.text,
    );
    final radiusMd = BorderRadius.circular(metrics.radiusMd);
    final radiusLg = BorderRadius.circular(metrics.radiusLg);
    final radiusXl = BorderRadius.circular(metrics.radiusXl);
    const borderSide = BorderSide(color: AppPalette.border);

    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppPalette.mango,
      onPrimary: AppPalette.ink,
      primaryContainer: AppPalette.mangoSoft,
      onPrimaryContainer: AppPalette.mango,
      secondary: AppPalette.clarity,
      onSecondary: AppPalette.ink,
      tertiary: AppPalette.smoke,
      onTertiary: AppPalette.ink,
      tertiaryContainer: AppPalette.smokeSoft,
      onTertiaryContainer: AppPalette.smoke,
      error: AppPalette.salve,
      onError: AppPalette.ink,
      surface: AppPalette.bg,
      onSurface: AppPalette.text,
      onSurfaceVariant: AppPalette.textMuted,
      surfaceContainerLowest: AppPalette.bg,
      surfaceContainerLow: AppPalette.surface1,
      surfaceContainer: AppPalette.surface1,
      surfaceContainerHigh: AppPalette.surface2,
      surfaceContainerHighest: AppPalette.surface3,
      outline: AppPalette.border,
      outlineVariant: AppPalette.border,
      inverseSurface: AppPalette.text,
      onInverseSurface: AppPalette.bg,
      inversePrimary: AppPalette.mango,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Color(0x00000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.bg,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const <ThemeExtension<dynamic>>[AppColors.dark, metrics],

      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.bg,
        foregroundColor: AppPalette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: AppPalette.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.mangoSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: metrics.iconSize,
            color: selected ? AppPalette.mango : AppPalette.textMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium!.copyWith(
            color: selected ? AppPalette.text : AppPalette.textMuted,
          );
        }),
      ),

      cardTheme: CardThemeData(
        color: AppPalette.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radiusXl, side: borderSide),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.mango,
          foregroundColor: AppPalette.ink,
          // Вимкнена лише під час надсилання: лишаємо манго, щоб не блимала сірим.
          disabledBackgroundColor: AppPalette.mango.withValues(alpha: 0.7),
          disabledForegroundColor: AppPalette.ink,
          minimumSize: Size(64, metrics.hitTarget),
          shape: RoundedRectangleBorder(borderRadius: radiusLg),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.text,
          backgroundColor: AppPalette.surface1,
          side: borderSide,
          minimumSize: Size(64, metrics.hitTarget),
          shape: RoundedRectangleBorder(borderRadius: radiusLg),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.clarity,
          minimumSize: Size.square(metrics.hitTarget),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppPalette.textMuted,
          minimumSize: Size.square(metrics.hitTarget),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surface1,
        selectedColor: AppPalette.mangoSoft,
        checkmarkColor: AppPalette.mango,
        side: borderSide,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        labelStyle: textTheme.labelLarge,
        padding: EdgeInsets.symmetric(horizontal: metrics.space2, vertical: metrics.space1),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface1,
        hintStyle: textTheme.bodyLarge!.copyWith(color: AppPalette.textMuted),
        prefixIconColor: AppPalette.textMuted,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: metrics.space3 + 2),
        border: OutlineInputBorder(borderRadius: radiusLg, borderSide: borderSide),
        enabledBorder: OutlineInputBorder(borderRadius: radiusLg, borderSide: borderSide),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusLg,
          borderSide: const BorderSide(color: AppPalette.clarity, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusLg,
          borderSide: const BorderSide(color: AppPalette.salve),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radiusLg,
          borderSide: const BorderSide(color: AppPalette.salve, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(borderRadius: radiusLg, borderSide: borderSide),
        errorStyle: textTheme.bodySmall!.copyWith(color: AppPalette.salve, fontWeight: FontWeight.w500),
        helperStyle: textTheme.bodySmall!.copyWith(color: AppPalette.textMuted),
        errorMaxLines: 2,
        suffixIconColor: AppPalette.textMuted,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.text,
        contentTextStyle: textTheme.bodyLarge!.copyWith(
          color: AppPalette.bg,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppPalette.bg,
        shape: RoundedRectangleBorder(borderRadius: radiusLg),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppPalette.surface1,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppPalette.textSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(metrics.radiusXl)),
        ),
      ),

      dividerTheme: const DividerThemeData(color: AppPalette.border, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppPalette.mango),
    );
  }
}
