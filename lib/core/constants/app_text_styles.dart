import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Type scale v2: Syne (display/headings/buttons), Inter (body),
/// Space Mono (receipt, passport fields, stamps).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get display => GoogleFonts.syne(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.1,
      );

  /// Same size on every screen title.
  static TextStyle get title => GoogleFonts.syne(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get section => GoogleFonts.syne(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardTitle => GoogleFonts.syne(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get badge => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      );

  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      );

  static TextStyle get mono => GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => GoogleFonts.syne(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.onPrimary,
      );

  // v1 names kept for older call sites.
  static TextStyle get displayLarge => display;
  static TextStyle get headingLarge => title;
  static TextStyle get headingMedium => section;
  static TextStyle get headingSmall => cardTitle;
  static TextStyle get bodyLarge => body.copyWith(fontSize: 16);
  static TextStyle get bodyMedium => body;
  static TextStyle get bodySmall => meta;
  static TextStyle get labelPrimary => badge.copyWith(fontSize: 13);
  static TextStyle get caption =>
      meta.copyWith(fontSize: 11, color: AppColors.textMuted);
  static TextStyle get priceTag => cardTitle.copyWith(fontSize: 14);
}
