import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography using Manrope.
/// All font sizes, weights and styles live here.
class AppTextStyle {
  AppTextStyle._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
    List<FontFeature>? features,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  // Headings
  static TextStyle get display => _base(
    size: 32,
    weight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle get h1 => _base(
    size: 24,
    weight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static TextStyle get h2 => _base(
    size: 20,
    weight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static TextStyle get h3 =>
      _base(size: 16, weight: FontWeight.w700, height: 1.35);

  // Body
  static TextStyle get bodyLarge =>
      _base(size: 15, weight: FontWeight.w500, height: 1.5);

  static TextStyle get body => _base(
    size: 14,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodyStrong =>
      _base(size: 14, weight: FontWeight.w600, height: 1.5);

  static TextStyle get bodySmall => _base(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  // Labels and captions
  static TextStyle get label => _base(
    size: 13,
    weight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
  );

  static TextStyle get caption => _base(
    size: 11,
    weight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  static TextStyle get overline => _base(
    size: 11,
    weight: FontWeight.w700,
    color: AppColors.textDisabled,
    letterSpacing: 1.0,
  );

  // Buttons
  static TextStyle get button => _base(
    size: 14,
    weight: FontWeight.w700,
    color: AppColors.onPrimary,
    letterSpacing: 0.1,
  );

  static TextStyle get buttonSecondary =>
      _base(size: 14, weight: FontWeight.w600);

  // Metrics (tabular figures keep numbers from jittering as they update)
  static TextStyle get metricValue => _base(
    size: 28,
    weight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
    features: const <FontFeature>[FontFeature.tabularFigures()],
  );

  static TextStyle get metricValueSm => _base(
    size: 20,
    weight: FontWeight.w700,
    height: 1.2,
    features: const <FontFeature>[FontFeature.tabularFigures()],
  );

  static TextStyle get metricUnit =>
      _base(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary);

  static TextStyle get tabular => _base(
    size: 13,
    weight: FontWeight.w600,
    features: const <FontFeature>[FontFeature.tabularFigures()],
  );

  // Navigation
  static TextStyle get navItem =>
      _base(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary);

  static TextStyle get navItemActive =>
      _base(size: 14, weight: FontWeight.w700, color: AppColors.primaryLight);

  // Charts
  static TextStyle get chartAxis =>
      _base(size: 11, weight: FontWeight.w600, color: AppColors.textSecondary);

  static TextStyle get chartLegend => _base(size: 12, weight: FontWeight.w600);

  /// Returns a copy of [style] tinted with [color].
  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);
}
