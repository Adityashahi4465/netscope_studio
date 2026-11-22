import 'package:flutter/material.dart';

/// Central color palette for NetScope Studio.
/// Never hardcode colors in views or widgets; add them here instead.
class AppColors {
  AppColors._();

  // Backgrounds and surfaces
  static const Color background = Color(0xFF0B1020);
  static const Color sidebar = Color(0xFF101729);
  static const Color surface = Color(0xFF171F32);
  static const Color surfaceElevated = Color(0xFF202B43);
  static const Color border = Color(0xFF2A3650);

  // Brand
  static const Color primary = Color(0xFF7187FF);
  static const Color primaryLight = Color(0xFFA9B6FF);
  static const Color primarySoft = Color(0x267187FF); // 15% alpha

  // Protocols
  static const Color tcp = Color(0xFF548FFF);
  static const Color tcpSoft = Color(0x26548FFF);
  static const Color udp = Color(0xFF22C79A);
  static const Color udpSoft = Color(0x2622C79A);

  // Status
  static const Color success = Color(0xFF26C38B);
  static const Color successSoft = Color(0x2626C38B);
  static const Color warning = Color(0xFFF2B84B);
  static const Color warningSoft = Color(0x26F2B84B);
  static const Color error = Color(0xFFF16B75);
  static const Color errorSoft = Color(0x26F16B75);
  static const Color info = Color(0xFF548FFF);

  // Text
  static const Color textPrimary = Color(0xFFF3F6FF);
  static const Color textSecondary = Color(0xFFA8B4CC);
  static const Color textDisabled = Color(0xFF6B7690);
  static const Color onPrimary = Color(0xFF0B1020);

  // Charts
  static const Color chartGrid = Color(0xFF232E47);
  static const Color chartTooltip = Color(0xFF202B43);

  // Overlays
  static const Color hover = Color(0x14FFFFFF); // 8% white
  static const Color pressed = Color(0x1FFFFFFF); // 12% white
  static const Color scrim = Color(0x99000000);
  static const Color shadow = Color(0x66000000);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[primary, Color(0xFF9A7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[background, Color(0xFF0E1428)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Returns the accent color for a protocol name ('tcp' or 'udp').
  static Color forProtocol(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'tcp':
        return tcp;
      case 'udp':
        return udp;
      default:
        return primary;
    }
  }
}
