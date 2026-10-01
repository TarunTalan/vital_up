import 'package:flutter/material.dart';

/// Raw colour palette — single source of truth, taken from the VitalUp Figma
/// file (page "design" → section "light theme", node 206:4919).
///
/// Widgets should NOT reference these directly for surface/text colours —
/// use `Theme.of(context).colorScheme` or the [VitalUpColors] extension
/// (via `context.vColors`) so dark mode keeps working. Use these constants
/// only inside the theme layer or for brand accents that never change.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------
  /// Primary cyan — Figma button/pri background.
  static const Color primary = Color(0xFF19C3E0);

  /// Darker cyan used for active input text — Figma #149CB3.
  static const Color primaryActive = Color(0xFF149CB3);

  /// Teal — secondary button text, filled-input helper text. Figma #0F7586.
  static const Color teal = Color(0xFF0F7586);

  /// Light cyan highlight used inside glass gradients — Figma #B8ECF5.
  static const Color highlight = Color(0xFFB8ECF5);
  static const Color highlightDark = Color(0xFF0D515D);

  // ---------------------------------------------------------------------------
  // Neutrals (Figma variables: darker / lighter / grey text)
  // ---------------------------------------------------------------------------
  static const Color darker = Color(0xFF1C1C1C);
  static const Color lighter = Color(0xFFFEFEFE);
  static const Color greyText = Color(0xFF757575);
  static const Color lightText = Color(0xFFE3E3E3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Text colour on the primary button — Figma #0C0C0C.
  static const Color buttonText = Color(0xFF0C0C0C);

  /// Secondary button outline — Figma #B9B9B9.
  static const Color secondaryBorder = Color(0xFFB9B9B9);

  /// Base grey used for glass fills/borders — Figma #BABABA.
  static const Color glassBase = Color(0xFFBABABA);

  /// Toast / hairline outline — Figma #D8D8D8.
  static const Color outline = Color(0xFFD8D8D8);
  static const Color outlineDark = Color(0xFF343434);

  /// Dark surfaces.
  static const Color surfaceDark = Color(0xFF1C1C1C);
  static const Color surfaceDarkElevated = Color(0xFF2A2A2A);

  // ---------------------------------------------------------------------------
  // Glass (Figma card/*, input/text, header)
  // ---------------------------------------------------------------------------
  /// rgba(186,186,186,0.13) — card / input fill.
  static const Color glassFill = Color(0x21BABABA);

  /// rgba(186,186,186,0.27) — card / input border.
  static const Color glassBorder = Color(0x45BABABA);

  /// rgba(186,186,186,0.30) — divider.
  static const Color divider = Color(0x4DBABABA);

  /// rgba(186,186,186,0.20) — progress-bar track.
  static const Color track = Color(0x33BABABA);

  /// Dark-mode equivalents.
  static const Color glassFillDark = Color(0x14FFFFFF);
  static const Color glassBorderDark = Color(0x26FFFFFF);
  static const Color dividerDark = Color(0x33FFFFFF);
  static const Color trackDark = Color(0x26FFFFFF);

  /// rgba(25,195,224,0.13) — filled input / header action fill.
  static const Color primaryFill = Color(0x2119C3E0);

  /// rgba(25,195,224,0.20) — icon badge background.
  static const Color primaryTint = Color(0x3319C3E0);

  /// rgba(25,195,224,0.27) — header action border.
  static const Color primaryBorder = Color(0x4519C3E0);

  /// Back-button fill — rgba(255,255,255,0.5).
  static const Color backButtonFill = Color(0x80FFFFFF);
  static const Color backButtonFillDark = Color(0x33FFFFFF);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------
  /// Error — Figma input/text error #E24B4A.
  static const Color error = Color(0xFFE24B4A);
  static const Color errorDark = Color(0xFFCC4D47);

  /// rgba(226,75,74,0.13) — error input fill.
  static const Color errorFill = Color(0x21E24B4A);

  /// Success green — Figma progress bar #4CAF50.
  static const Color success = Color(0xFF4CAF50);

  /// rgba(76,175,80,0.20) — success icon badge background.
  static const Color successTint = Color(0x334CAF50);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningTint = Color(0x33FF9800);
  static const Color info = Color(0xFF2675ED);

  // ---------------------------------------------------------------------------
  // Decorative / misc
  // ---------------------------------------------------------------------------
  static const Color blobPurple = Color(0xFFE083FF);
  static const Color blobMint = Color(0xFF67FFAB);
  static const Color link = Color(0xFF2675ED);
  static const Color termsLink = Color(0xFF1367E6);
  static const Color indicatorInactive = Color(0xFFD8D8D8);
  static const Color navSelected = Color(0xFF2DB6A3);
  static const Color navUnselected = Color(0xFF9E9E9E);
  static const Color snackBarBg = Color(0xFF1C1C1C);

  /// Macro-nutrient accents — Figma macro bars (food scanner 1172:7901),
  /// shared by dashboard, diet plan and scanner.
  static const Color protein = Color(0xFF00BFA5);
  static const Color carbs = Color(0xFFF5AE17);
  static const Color fat = Color(0xFFB786F7);

  /// Food scanner — Figma macro bars (1172:7901) and colour grades (1935:7668).
  static const Color scanProtein = protein;
  static const Color scanCarbs = carbs;
  static const Color scanFat = fat;
  static const Color gradeGood = Color(0xFF4CAF50);
  static const Color gradeModerate = Color(0xFFF09F5C);
  static const Color gradeBad = Color(0xFFF0685C);

  /// Food scanner camera overlays (always drawn over a live preview).
  static const Color cameraBackdrop = Color(0xFF101316);
  static const Color cameraScrim = Color(0x66000000);
  static const Color cameraControlFill = Color(0x80FFFFFF);
  static const Color cameraCaptureRing = Color(0x33FFFFFF);

  /// Water-intake accent (wave fill, quick-add chips).
  static const Color water = Color(0xFF42A5F5);

  /// Sleep accent (sleep trend bars).
  static const Color sleep = Color(0xFF7C83FD);

  /// Stress check-in ramp, level 1 (very calm) → 5 (very stressed).
  static const List<Color> stressLevels = [
    Color(0xFF26C6A6),
    Color(0xFF8BD46E),
    Color(0xFFFFC54D),
    Color(0xFFFF9248),
    Color(0xFFF25F5C),
  ];

  /// Activity goal metric accents.
  static const Color activitySteps = primary;
  static const Color activityDistance = Color(0xFF26A69A);
  static const Color activityCalories = Color(0xFFFF7043);
  static const Color activityMinutes = Color(0xFFFFC107);
  static const Color activityWorkouts = Color(0xFF9C6ADE);

  /// Streak flame on the stress check-in and the score card.
  static const Color streak = Color(0xFFFF7A3D);

  /// Gamification score categories.
  static const Color scoreNutrition = protein;
  static const Color scoreLifestyle = sleep;
  static const Color scoreFitness = activityCalories;
  static const Color scoreBonus = activityMinutes;

  /// Leaderboard podium: 1st, 2nd, 3rd.
  static const Color rankGold = Color(0xFFFFC233);
  static const Color rankSilver = Color(0xFFB4BDC6);
  static const Color rankBronze = Color(0xFFD48A55);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  /// Subtle cyan sheen used on Figma glass cards:
  /// linear-gradient(~110deg, rgba(184,236,245,0) 53%, rgba(184,236,245,0.2) 97%)
  static const LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.53, 0.97],
    colors: [Color(0x00B8ECF5), Color(0x33B8ECF5)],
  );

  /// Highlighted insight card — Figma card/insight on detail pages.
  static const LinearGradient insightSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.6, 1.0],
    colors: [Color(0xCC19C3E0), Color(0x0019C3E0), Color(0xCC19C3E0)],
  );

  // ---------------------------------------------------------------------------
  // Onboarding accents
  // ---------------------------------------------------------------------------
  /// Gender choice tiles — Figma onboarding/info/gender.
  static const Color genderMale = Color(0xFF465EEB);
  static const Color genderFemale = Color(0xFFF463BA);

  /// BPM heart pulse glow.
  static const Color heartGlow = Color(0xFFFF3DBF);
  static const Color heartGlowSoft = Color(0xFFFF6FD8);
}

/// Vita health coach — Figma section "Health coach" (1893:14544).
class VitaColors {
  VitaColors._();

  /// "Meet **Vita**" highlight and home tile labels — Figma #17B0CA.
  static const Color accent = Color(0xFF17B0CA);

  /// Bot chat bubble — Figma #E8F9FC fill, #B8ECF5 border, teal text.
  static const Color botBubble = Color(0xFFE8F9FC);
  static const Color botBubbleBorder = AppColors.highlight;
  static const Color botText = AppColors.teal;

  /// User chat bubble and quick-reply chips — teal fill, lighter text.
  static const Color userBubble = AppColors.teal;
  static const Color userText = AppColors.lighter;

  /// Composer placeholder + idle send button — Figma #A2B8C8.
  static const Color composerMuted = Color(0xFFA2B8C8);

  /// Calorie pill on diet plan cards — highlight fill, Figma #0B5865 text.
  static const Color pillFill = AppColors.highlight;
  static const Color pillText = Color(0xFF0B5865);

  /// Vita avatar placeholders — Figma #E3E3E3 (large) / #C7C5C5 (insight).
  static const Color avatar = AppColors.lightText;
  static const Color avatarInsight = Color(0xFFC7C5C5);

  /// Health analysis icon badge — rgba(0,191,165,0.2).
  static const Color signalBadge = Color(0x3300BFA5);
}

/// Fixed accents for activity tracking (map markers, soundtrack icons).
class ActivityColors {
  ActivityColors._();

  /// Route start marker on the map.
  static const Color mapStartPoint = Color(0xFFFF5722);

  /// Outline around map markers (start point, location puck).
  static const Color mapMarkerStroke = AppColors.white;

  /// Soundtrack icon accents.
  static const Color accentAmber = Color(0xFFFFC107);
  static const Color accentPurple = Color(0xFF9C27B0);
}
