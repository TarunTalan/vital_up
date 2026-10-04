import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography — Figma text styles mapped onto the Material [TextTheme].
///
/// Widgets must use `Theme.of(context).textTheme.<style>` (or `context.text`)
/// and only `.copyWith(color:/fontWeight:)` — never a literal `fontSize`.
/// Font sizes are scaled app-wide by `ResponsiveTextScale` in `main.dart`.
///
/// | Figma style          | Size/weight | TextTheme slot                 |
/// |----------------------|-------------|--------------------------------|
/// | Large Title          | 36 / 600    | displayLarge                   |
/// | heading 1            | 32 / 600    | headlineLarge                  |
/// | (legacy large title) | 30 / 600    | titleLarge                     |
/// | heading 2            | 26 / 500    | displayMedium, headlineMedium  |
/// | heading 3            | 20 / 500    | displaySmall, headlineSmall, titleMedium |
/// | body 16 med          | 16 / 500    | titleSmall, labelLarge         |
/// | body reg 16          | 16 / 400    | bodyLarge                      |
/// | small reg 14         | 14 / 400    | bodyMedium, labelMedium        |
/// | small reg 12         | 12 / 400    | bodySmall, labelSmall          |
/// | caption 12 (mono)    | 12 / 500    | [AppTextStyles.caption]        |
/// | metric (light)       | 36 / 300    | [AppTextStyles.metric]         |
/// | metric large         | 48 / 400    | [AppTextStyles.metricLarge]    |
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'SFProRounded';

  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 36,
    height: 1.1,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.15,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 22,
    height: 1.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 1.25,
  );

  static const TextStyle body16Medium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.25,
  );

  static const TextStyle body16 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.4,
    letterSpacing: 0.24, // Figma 1.5%
  );

  static const TextStyle small14 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.35,
  );

  static const TextStyle small12 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.35,
  );

  /// Big numeric readouts on cards (Figma card/big "3h 54m").
  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w300,
    fontSize: 28,
    height: 1.1,
  );

  /// Hero numeric readouts on detail pages (Figma "7h 32m").
  static const TextStyle metricLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 40,
    height: 1.0,
  );

  /// Figma "caption 12" — JetBrains Mono Medium, used for uppercase card
  /// eyebrows like "TODAY'S INSIGHTS". Falls back to the app font offline.
  static TextStyle get caption => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0.5,
      ).copyWith(fontFamilyFallback: const [fontFamily]);

  static const TextTheme textTheme = TextTheme(
    displayLarge: largeTitle,
    displayMedium: heading2,
    displaySmall: heading3,
    headlineLarge: heading1,
    headlineMedium: heading2,
    headlineSmall: heading3,
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 30,
      height: 1.15,
    ),
    titleMedium: heading3,
    titleSmall: body16Medium,
    bodyLarge: body16,
    bodyMedium: small14,
    bodySmall: small12,
    labelLarge: body16Medium,
    labelMedium: small14,
    labelSmall: small12,
  );
}
