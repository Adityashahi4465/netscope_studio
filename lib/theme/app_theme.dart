import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_style.dart';

/// Builds the application's dark [ThemeData].
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final ThemeData base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
    );

    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.udp,
      onSecondary: AppColors.onPrimary,
      tertiary: AppColors.tcp,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final TextTheme textTheme = base.textTheme
        .apply(
          fontFamily: GoogleFonts.manrope().fontFamily,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      hoverColor: AppColors.hover,
      highlightColor: Colors.transparent,
      splashColor: AppColors.primarySoft,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: AppDimensions.borderWidth,
        space: AppDimensions.borderWidth,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppDimensions.iconMd,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyle.h2,
      ),
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(0, AppDimensions.controlHeight),
          padding: AppDimensions.buttonPadding,
          elevation: 0,
          textStyle: AppTextStyle.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMd,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, AppDimensions.controlHeight),
          padding: AppDimensions.buttonPadding,
          textStyle: AppTextStyle.buttonSecondary,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMd,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: AppTextStyle.buttonSecondary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusSm,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          hoverColor: AppColors.hover,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        textStyle: AppTextStyle.bodySmall.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppDimensions.borderRadiusSm,
          border: Border.all(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppTextStyle.bodyStrong,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMd,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceElevated,
        circularTrackColor: AppColors.surfaceElevated,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceElevated,
        thumbColor: AppColors.primaryLight,
        overlayColor: AppColors.primarySoft,
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surfaceElevated,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll<Color>(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(AppColors.border),
        radius: Radius.circular(AppDimensions.radiusPill),
        thickness: WidgetStatePropertyAll<double>(6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        textStyle: AppTextStyle.bodyStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          side: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  static InputDecorationTheme get _inputDecorationTheme {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: AppDimensions.borderRadiusMd,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      isDense: true,
      contentPadding: AppDimensions.inputPadding,
      hintStyle: AppTextStyle.body.copyWith(color: AppColors.textDisabled),
      labelStyle: AppTextStyle.label,
      floatingLabelStyle: AppTextStyle.label.copyWith(
        color: AppColors.primaryLight,
      ),
      errorStyle: AppTextStyle.bodySmall.copyWith(color: AppColors.error),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(
        AppColors.primary,
        AppDimensions.borderWidthFocused,
      ),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(
        AppColors.error,
        AppDimensions.borderWidthFocused,
      ),
      disabledBorder: border(AppColors.chartGrid),
    );
  }
}
