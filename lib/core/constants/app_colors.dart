import 'package:flutter/material.dart';

/// Design tokens v2 — mirror of the variables in design/street_coffee.pen.
/// Lime is the only accent; WhatsApp green is reserved for the WA icon/bubble.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF9FE444);
  static const Color primaryPressed = Color(0xFF7BC419);
  static const Color primarySoft = Color(0x1F9FE444);
  static const Color onPrimary = Color(0xFF0E0E0E);
  static const Color passGradientEnd = Color(0xFFE4F76A);

  // Surfaces
  static const Color bg = Color(0xFF0E0E0E);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceAlt = Color(0xFF222222);
  static const Color input = Color(0xFF262626);
  static const Color tabBar = Color(0xE61E1E1E);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF8A8A8A);

  // Status
  static const Color open = primary;
  static const Color closed = Color(0xFFFF6B5E);
  static const Color closedSoft = Color(0x1FFF6B5E);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappBubble = Color(0xFF103B2B);

  // Misc
  static const Color divider = Color(0xFF2C2C2C);
  static const Color star = Color(0xFFFFC107);
  static const Color overlay = Color(0x8C000000);

  // v1 names kept so older call sites keep compiling.
  static const Color bgDark = bg;
  static const Color bgCard = surface;
  static const Color bgCardAlt = surfaceAlt;
  static const Color bgInput = input;
  static const Color primaryDark = primaryPressed;

  static const LinearGradient passGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFC8F56A), primary, Color(0xFF5E9A1C)],
    stops: [0, 0.45, 1],
  );

  static const SweepGradient ringGradient = SweepGradient(
    colors: [primary, passGradientEnd, primary],
  );
}
