import 'package:flutter/material.dart';

/// Spacing, sizing, radius and elevation tokens — taken from the VitalUp
/// Figma file (412dp-wide frames). Page gutter is fixed at 16dp by product
/// decision (Figma shows 20).
///
/// These are *design* values for the 412dp reference width. For values that
/// must adapt to the screen, wrap them with the helpers in
/// `core/utils/responsive.dart` (e.g. `context.w(AppDimens.iconBadge)`).
class AppDimens {
  AppDimens._();

  // ---------------------------------------------------------------------------
  // Reference frame
  // ---------------------------------------------------------------------------
  static const double designWidth = 412.0;
  static const double designHeight = 917.0;

  /// Maximum width of page content on tablets / large screens.
  static const double maxContentWidth = 600.0;

  /// Tablet breakpoint (shortest side).
  static const double tabletBreakpoint = 600.0;

  /// Small-phone breakpoint (width).
  static const double smallPhoneBreakpoint = 360.0;

  // ---------------------------------------------------------------------------
  // Spacing scale
  // ---------------------------------------------------------------------------
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  /// Page horizontal gutter. Figma uses 20, but the product decision is 16dp
  /// on every phone (full-width buttons/cards sit inside this gutter).
  static const double gutter = 16.0;
  static const double gutterTablet = 32.0;

  /// Vertical gap between stacked page sections — Figma layout/content gap-24.
  static const double sectionGap = 24.0;

  /// Gap between cards in a list — Figma Section gap-12.
  static const double cardGap = 12.0;

  // ---------------------------------------------------------------------------
  // Radii
  // ---------------------------------------------------------------------------
  static const double radiusXs = 4.0;
  static const double radiusSm = 10.0;
  static const double radiusToast = 12.0;
  static const double radiusButton = 14.0;
  static const double radiusCard = 16.0;
  static const double radiusInput = 20.0;
  static const double radiusDialog = 20.0;
  static const double radiusSheet = 24.0;
  static const double radiusNavBar = 58.0;
  static const double radiusPill = 999.0;

  // ---------------------------------------------------------------------------
  // Component sizes
  // ---------------------------------------------------------------------------
  /// Figma button/pri & button/sec.
  static const double buttonHeight = 48.0;
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const double buttonGap = 8.0;

  /// Figma input/text field.
  static const double inputHeight = 56.0;
  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0);
  static const double inputLabelGap = 6.0;

  /// Figma button/ArrowLeft (24 icon + 12 padding).
  static const double backButtonSize = 48.0;

  /// Figma header action button (calendar etc.).
  static const double headerActionSize = 44.0;

  /// Figma icon badge (coloured circle behind card icons).
  static const double iconBadge = 40.0;
  static const double iconBadgeLarge = 48.0;

  static const double quickActionWidth = 100.0;

  /// Figma bottom nav bar (bars & panels/tab).
  static const double navBarItemHeight = 42.0;
  static const EdgeInsets navBarPadding =
      EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0);
  static const double navBarBottomOffset = 16.0;

  /// Figma segmented tab (Move / Rest / Fuel / Vitals).
  static const double segmentHeight = 41.0;

  /// Figma progress bar.
  static const double progressHeight = 8.0;

  /// Dialog / sheet drag handle.
  static const double sheetHandleWidth = 40.0;
  static const double sheetHandleHeight = 4.0;

  /// Food scanner — Figma scan bar (1984:6979) and colour grades (1935:7668).
  static const double captureButtonSize = 72.0;
  static const double captureButtonInner = 54.0;
  static const double scanBarGap = 48.0;
  static const double scanFrameRadius = 24.0;
  static const double scanFrameBracket = 88.0;
  static const double scoreMeterSize = 150.0;
  static const double scoreMeterStroke = 12.0;
  static const double numberBadge = 24.0;
  static const double bulletDot = 6.0;

  // ---------------------------------------------------------------------------
  // Icons
  // ---------------------------------------------------------------------------
  static const double iconXs = 16.0;
  static const double iconSm = 18.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // ---------------------------------------------------------------------------
  // Card padding (Figma card/big: px-12 py-20, card/small: px-20 py-16)
  // ---------------------------------------------------------------------------
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingCompact =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(20.0);
  static const double cardInnerGap = 12.0;

  /// Figma toast/info.
  static const EdgeInsets toastPadding =
      EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0);

  // ---------------------------------------------------------------------------
  // Borders / effects
  // ---------------------------------------------------------------------------
  static const double borderThin = 1.0;

  /// Content opacity of disabled / read-only inputs.
  static const double disabledOpacity = 0.55;
  static const double borderThick = 2.0;
  static const double hairline = 0.5;

  /// Figma glass background-blur radius (15.3 on cards/inputs).
  static const double glassBlur = 15.3;

  /// Figma "iOS/Blur - 20".
  static const double headerBlur = 20.0;

  // ---------------------------------------------------------------------------
  // Profile / diet plan
  // ---------------------------------------------------------------------------
  static const double iconXxl = 48.0;
  static const double avatarLarge = 96.0;
  static const double avatarSmall = 32.0;
  static const double profileHeaderHeight = 260.0;
  static const double unitFieldWidth = 96.0;
  static const double donutHole = 60.0;
  static const double donutThickness = 30.0;

  /// Dashboard: calorie ring and water-wave panel.
  static const double calorieRing = 80.0;
  static const double calorieRingStroke = 8.0;
  static const double waterWaveHeight = 120.0;

  /// Dashboard: height of a half-width tracker tile at 1x text scale.
  static const double dashboardTileHeight = 240.0;

  /// Dashboard trend charts: 7-day mini chart on cards, full chart on the
  /// detail pages.
  static const double miniChartHeight = 64.0;
  static const double trendChartHeight = 200.0;
  static const double chartBarWidth = 14.0;
  static const double chartBarWidthMini = 10.0;
  static const double chartBarWidthDense = 6.0;
  static const double chartAxisReserved = 36.0;
  static const double chartLabelReserved = 20.0;
  static const int chartGoalDash = 4;

  /// Opacity of past-day bars (today's bar is fully opaque).
  static const double chartInactiveAlpha = 0.4;

  /// Trackers: progress ring on detail heroes, status chip, quick-log tiles,
  /// stage/legend dots and the alpha used for tinted fills and borders.
  static const double trackerRing = 96.0;
  static const double trackerRingStroke = 10.0;
  static const double trackerTile = 96.0;
  static const double trackerPreset = 72.0;
  static const double stageBarHeight = 8.0;
  static const double legendDot = 6.0;
  static const double tintAlpha = 0.12;
  static const double tintBorderAlpha = 0.3;
  static const double completedOpacity = 0.85;

  /// Stress check-in: emoji faces, mood strip dots, confetti.
  static const double moodFaceSize = 24.0;
  static const double moodFaceBox = 44.0;
  static const double moodFaceSelectedScale = 1.25;
  static const double moodStripDot = 14.0;
  static const double confettiParticle = 6.0;
  static const double confettiSpread = 90.0;

  /// Gamification: level ring on the score card, badge grid tiles,
  /// leaderboard podium avatars and rank column.
  static const double levelRing = 72.0;
  static const double levelRingStroke = 7.0;
  static const double badgeTile = 56.0;
  static const double badgeGridMinWidth = 104.0;
  // Tall enough for a locked badge's progress bar and "7 of 10".
  static const double badgeTileAspect = 0.68;
  static const double badgeProgressHeight = 4.0;
  static const double badgeLockedOpacity = 0.35;
  static const double podiumAvatarFirst = 64.0;
  static const double podiumAvatarOther = 52.0;
  static const double podiumStepFirst = 72.0;
  static const double podiumStepSecond = 52.0;
  static const double podiumStepThird = 40.0;
  static const double rankColumnWidth = 32.0;
  static const double celebrationBadge = 96.0;

  /// Notifications: unread count on the header bell, unread dot on rows.
  static const double unreadBadge = 18.0;
  static const double unreadDot = 8.0;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------
  /// Figma Tabs/Default selected pill and num-input (OTP) box radius.
  static const double radiusTab = 18.0;

  /// Welcome carousel page indicator dots.
  static const double pageIndicatorActive = 16.0;
  static const double pageIndicatorInactive = 12.0;

  /// Password-changed success badge (outer circle) and its tick.
  static const double successBadge = 132.0;
  static const double successTick = 61.0;

  /// Figma loader animation: 50dp icons on a 60dp grid.
  static const double loaderIcon = 50.0;
  static const double loaderSize = 110.0;

  /// Splash logo box.
  static const double splashLogo = 220.0;

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------
  /// Figma num input: 52dp square +/- steppers around a 108dp value box.
  static const double numberStepperSize = 52.0;
  static const double numberFieldWidth = 108.0;
  static const double numberFieldHeight = 70.0;

  /// Onboarding Skip / Next buttons (Figma 108 wide) — used as a min width.
  static const double actionButtonMinWidth = 108.0;

  /// Selectable option tile (activity / diet) and gender choice tile.
  static const double optionTileHeight = 64.0;
  static const double choiceTileHeight = 100.0;

  /// Heart illustrations on the BP / BPM steps.
  static const double onboardingIllustration = 162.0;
}

/// Elevation / shadow tokens, from Figma effect styles.
class AppShadows {
  AppShadows._();

  /// Figma "shadow black y" — back button and floating circular controls.
  static const List<BoxShadow> shadowY = [
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 1),
    BoxShadow(color: Color(0x12000000), offset: Offset(0, 2), blurRadius: 2),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 5), blurRadius: 3),
    BoxShadow(color: Color(0x03000000), offset: Offset(0, 8), blurRadius: 3),
  ];

  /// Figma "elevated" — bottom nav bar, floating panels.
  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 3),
    BoxShadow(color: Color(0x17000000), blurRadius: 6),
    BoxShadow(color: Color(0x0D000000), blurRadius: 8),
    BoxShadow(color: Color(0x03000000), blurRadius: 9),
  ];

  /// Figma "bb, bs" — soft card lift.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x03000000), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(color: Color(0x03000000), offset: Offset(0, 4), blurRadius: 5),
    BoxShadow(color: Color(0x05000000), offset: Offset(0, 9), blurRadius: 7),
  ];

  /// Selected segmented-tab drop shadow.
  static const List<BoxShadow> segment = [
    BoxShadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 1),
    BoxShadow(color: Color(0x26000000), offset: Offset(0, 1), blurRadius: 1.5),
  ];

  /// Focus glow around an active input.
  static const List<BoxShadow> inputFocus = [
    BoxShadow(color: Color(0x1A19C3E0), blurRadius: 3),
    BoxShadow(color: Color(0x1719C3E0), blurRadius: 6),
    BoxShadow(color: Color(0x0D19C3E0), blurRadius: 8),
  ];
}

/// Animation durations used across the app.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Page push / pop (see `AppPageTransitionsBuilder`).
  static const Duration page = Duration(milliseconds: 400);
  static const Duration pageReverse = Duration(milliseconds: 320);

  /// Mood face bounce and check-in confetti burst.
  static const Duration bounce = Duration(milliseconds: 450);
  static const Duration confetti = Duration(milliseconds: 900);
}

/// Vita health coach sizes — Figma section 1893:14544.
class VitaDimens {
  VitaDimens._();

  static const double avatarLarge = 100.0;
  static const double avatarSmall = 32.0;

  /// List/info cards on the Vita sub-pages (p-20).
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);

  /// Home feature tiles.
  static const double tileHeight = 48.0;
  static const double tileGapX = 9.0;
  static const double tileGapY = 12.0;
  static const double homeGap = 23.0;

  /// Chat bubbles: 28 radius on three corners; widths as a fraction of the
  /// 371dp chat column (bot 314, user 295).
  static const double bubbleRadius = 28.0;
  static const double botBubbleFraction = 314 / 371;
  static const double userBubbleFraction = 295 / 371;
  static const double bubbleLineHeight = 23 / 16;
  static const double messageGap = 28.0;
  static const double chatSectionGap = 42.0;

  static const double composerHeight = 100.0;
  static const double sendButton = 52.0;

  /// Health analysis signal badge.
  static const double signalBadge = 40.0;
  static const double signalBadgeRadius = 13.0;

  /// Diet plan calorie pill + indented meal items.
  static const double pillRadius = 30.0;
  static const EdgeInsets pillPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  static const double mealItemIndent = 17.0;
}

/// Map annotation sizes for the activity tracking map.
class ActivityMapDimens {
  ActivityMapDimens._();

  static const double routeWidth = 5.0;
  static const double startRadius = 10.0;
  static const double startStroke = 3.0;
  static const double puckRadius = 8.0;
  static const double puckStroke = 2.0;
}
