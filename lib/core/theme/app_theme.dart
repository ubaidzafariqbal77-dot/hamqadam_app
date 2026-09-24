import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';

/// The app's single light theme for HamQadam, built on the #E85A8A brand
/// colour.
///
/// There is deliberately no dark counterpart. The product is a light-only
/// matrimonial app — a black canvas washes out the rose artwork the whole flow
/// is designed around — so the theme is not built and no screen can switch to
/// it. Every surface below is the light token; the dark palette in
/// [AppColors] is what is left of the removed mode.
///
/// Everything is centralised here: AppBar, bottom navigation, buttons, inputs,
/// cards, dialogs, chips, switches, pickers, snackbars — so screens never need
/// hardcoded colours. Pink carries action; ink carries content.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build();

  static ThemeData _build() {
    const Color background = AppColors.lightBackground;
    const Color surface = AppColors.lightSurface;
    const Color surfaceAlt = AppColors.lightSurfaceAlt;
    const Color textPrimary = AppColors.lightTextPrimary;
    const Color textSecondary = AppColors.lightTextSecondary;
    const Color border = AppColors.lightBorder;
    const Color divider = AppColors.lightDivider;
    // Hints/placeholders use quiet neutral ink instead of brand colour.
    const Color hint = AppColors.lightTextHint;

    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.goldLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      tertiary: AppColors.gold,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: surfaceAlt,
      outline: border,
      outlineVariant: divider,
    );

    final TextTheme textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: textTheme,
      hintColor: hint,
      iconTheme: const IconThemeData(color: textPrimary),
      splashFactory: InkRipple.splashFactory,
      dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 1),

      // ---- AppBar: brand background, white content -------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 3,
        shadowColor: Colors.black26,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.title.copyWith(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // ---- Bottom navigation: brand background, white items ----------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.white.withValues(alpha: 0.24),
        elevation: 8,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((Set<WidgetState> s) {
          final bool selected = s.contains(WidgetState.selected);
          return IconThemeData(color: selected ? Colors.white : Colors.white70);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((Set<WidgetState> s) {
          final bool selected = s.contains(WidgetState.selected);
          return AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primary,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ---- Buttons ---------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTextStyles.button,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTextStyles.button,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),

      // ---- Inputs: calm neutral fields, brand only on focus ----------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: AppTextStyles.body.copyWith(color: hint),
        labelStyle: AppTextStyles.body.copyWith(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),

      // ---- Selection controls: brand active state -------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) =>
            Colors.white),
        trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.grey.shade300),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : null),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),

      // ---- Chips: neutral resting state, brand when selected ---------------
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: AppTextStyles.caption.copyWith(color: textPrimary),
        secondaryLabelStyle: AppTextStyles.caption.copyWith(color: Colors.white),
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
      ),

      // ---- Surfaces --------------------------------------------------------
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: AppTextStyles.title.copyWith(color: textPrimary),
        contentTextStyle: AppTextStyles.body.copyWith(color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A1620),
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        actionTextColor: AppColors.goldLight,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),

      // ---- Pickers: brand header ------------------------------------------
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        todayBackgroundColor: WidgetStatePropertyAll<Color>(AppColors.primary.withValues(alpha: 0.12)),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: surface,
        hourMinuteColor: surfaceAlt,
        dialHandColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: AppColors.primary,
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: AppTextStyles.display.copyWith(color: primary),
      headlineMedium: AppTextStyles.headline.copyWith(color: primary),
      titleLarge: AppTextStyles.title.copyWith(color: primary),
      titleMedium: AppTextStyles.subtitle.copyWith(color: primary),
      bodyLarge: AppTextStyles.body.copyWith(color: primary),
      bodyMedium: AppTextStyles.body.copyWith(color: secondary),
      labelLarge: AppTextStyles.label.copyWith(color: primary),
      labelSmall: AppTextStyles.caption.copyWith(color: secondary),
    );
  }
}
