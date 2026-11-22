import 'package:flutter/material.dart';

/// Central spacing, radii, sizes and layout constants.
class AppDimensions {
  AppDimensions._();

  // Spacing scale
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 999;

  static const BorderRadius borderRadiusSm =
      BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd =
      BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg =
      BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl =
      BorderRadius.all(Radius.circular(radiusXl));

  // Padding presets
  static const EdgeInsets pagePadding = EdgeInsets.all(xl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(xl);
  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: xl, vertical: md);

  // Control heights
  static const double controlHeight = 44;
  static const double controlHeightSm = 36;
  static const double controlHeightLg = 52;

  // Borders
  static const double borderWidth = 1;
  static const double borderWidthFocused = 1.5;

  // Icons
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;

  // Layout
  static const double sidebarWidth = 248;
  static const double sidebarCollapsedWidth = 72;
  static const double topBarHeight = 64;
  static const double sidebarItemHeight = 44;
  static const double maxContentWidth = 1400;
  static const double minWindowWidth = 960;
  static const double minWindowHeight = 640;

  // Responsive breakpoints (content width)
  static const double breakpointCompact = 900;
  static const double breakpointMedium = 1200;

  // Components
  static const double metricCardMinWidth = 200;
  static const double chartHeight = 280;
  static const double chartHeightSm = 200;
  static const double statusDotSize = 8;
  static const double progressBarHeight = 6;

  // Motion
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);
  static const Curve animCurve = Curves.easeOutCubic;
}