import 'package:flutter/material.dart';

/// Custom theme extension to support specific VitalUp brand colors
/// that are not part of the standard Material [ColorScheme].
class VitalUpColors extends ThemeExtension<VitalUpColors> {
  final Color? header;
  final Color? button;
  final Color? textFieldText;
  final Color? outlineFocused;
  final Color? errorTextField;
  final Color? grayText;
  final Color? tab;
  final Color? preText;
  final Color? surfaceFocused;
  final Color? link;
  final Color? navBg;
  final Color? navSelected;
  final Color? navUnselected;

  // --- Figma-specific tokens ---
  /// Unfocused input border / tab bar container border — Figma #BABABA
  final Color? inputBorder;
  /// Focused input border — same as primary/brand cyan
  final Color? inputBorderFocused;
  /// Secondary button background — Figma #FEFEFE
  final Color? secondaryButtonBg;
  /// Secondary button text/icon color — Figma #0F7586
  final Color? secondaryButtonText;
  /// Decorative blob — purple, Figma #E083FF
  final Color? blobPurple;
  /// Decorative blob — mint green, Figma #67FFAB
  final Color? blobMint;
  /// Welcome screen illustration circle — Figma #B8ECF5
  final Color? illustrationCircle;
  /// Terms & conditions link color — Figma #1367E6
  final Color? termsLink;
  /// Inactive page indicator — Figma #D8D8D8
  final Color? indicatorInactive;
  /// Button text (dark on primary) — Figma #0C0C0C
  final Color? buttonText;
  /// Tab bar container background color — Figma #BABABA
  final Color? tabBarBg;
  /// Active tab text color — Figma #FEFEFE
  final Color? tabTextActive;
  /// Inactive tab text color — Figma #757575
  final Color? tabTextInactive;

  const VitalUpColors({
    required this.header,
    required this.button,
    required this.textFieldText,
    required this.outlineFocused,
    required this.errorTextField,
    required this.grayText,
    required this.tab,
    required this.preText,
    required this.surfaceFocused,
    required this.link,
    required this.navBg,
    required this.navSelected,
    required this.navUnselected,
    required this.inputBorder,
    required this.inputBorderFocused,
    required this.secondaryButtonBg,
    required this.secondaryButtonText,
    required this.blobPurple,
    required this.blobMint,
    required this.illustrationCircle,
    required this.termsLink,
    required this.indicatorInactive,
    required this.buttonText,
    required this.tabBarBg,
    required this.tabTextActive,
    required this.tabTextInactive,
  });

  @override
  VitalUpColors copyWith({
    Color? header,
    Color? button,
    Color? textFieldText,
    Color? outlineFocused,
    Color? errorTextField,
    Color? grayText,
    Color? tab,
    Color? preText,
    Color? surfaceFocused,
    Color? link,
    Color? navBg,
    Color? navSelected,
    Color? navUnselected,
    Color? inputBorder,
    Color? inputBorderFocused,
    Color? secondaryButtonBg,
    Color? secondaryButtonText,
    Color? blobPurple,
    Color? blobMint,
    Color? illustrationCircle,
    Color? termsLink,
    Color? indicatorInactive,
    Color? buttonText,
    Color? tabBarBg,
    Color? tabTextActive,
    Color? tabTextInactive,
  }) {
    return VitalUpColors(
      header: header ?? this.header,
      button: button ?? this.button,
      textFieldText: textFieldText ?? this.textFieldText,
      outlineFocused: outlineFocused ?? this.outlineFocused,
      errorTextField: errorTextField ?? this.errorTextField,
      grayText: grayText ?? this.grayText,
      tab: tab ?? this.tab,
      preText: preText ?? this.preText,
      surfaceFocused: surfaceFocused ?? this.surfaceFocused,
      link: link ?? this.link,
      navBg: navBg ?? this.navBg,
      navSelected: navSelected ?? this.navSelected,
      navUnselected: navUnselected ?? this.navUnselected,
      inputBorder: inputBorder ?? this.inputBorder,
      inputBorderFocused: inputBorderFocused ?? this.inputBorderFocused,
      secondaryButtonBg: secondaryButtonBg ?? this.secondaryButtonBg,
      secondaryButtonText: secondaryButtonText ?? this.secondaryButtonText,
      blobPurple: blobPurple ?? this.blobPurple,
      blobMint: blobMint ?? this.blobMint,
      illustrationCircle: illustrationCircle ?? this.illustrationCircle,
      termsLink: termsLink ?? this.termsLink,
      indicatorInactive: indicatorInactive ?? this.indicatorInactive,
      buttonText: buttonText ?? this.buttonText,
      tabBarBg: tabBarBg ?? this.tabBarBg,
      tabTextActive: tabTextActive ?? this.tabTextActive,
      tabTextInactive: tabTextInactive ?? this.tabTextInactive,
    );
  }

  @override
  VitalUpColors lerp(ThemeExtension<VitalUpColors>? other, double t) {
    if (other is! VitalUpColors) return this;
    return VitalUpColors(
      header: Color.lerp(header, other.header, t),
      button: Color.lerp(button, other.button, t),
      textFieldText: Color.lerp(textFieldText, other.textFieldText, t),
      outlineFocused: Color.lerp(outlineFocused, other.outlineFocused, t),
      errorTextField: Color.lerp(errorTextField, other.errorTextField, t),
      grayText: Color.lerp(grayText, other.grayText, t),
      tab: Color.lerp(tab, other.tab, t),
      preText: Color.lerp(preText, other.preText, t),
      surfaceFocused: Color.lerp(surfaceFocused, other.surfaceFocused, t),
      link: Color.lerp(link, other.link, t),
      navBg: Color.lerp(navBg, other.navBg, t),
      navSelected: Color.lerp(navSelected, other.navSelected, t),
      navUnselected: Color.lerp(navUnselected, other.navUnselected, t),
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t),
      inputBorderFocused:
          Color.lerp(inputBorderFocused, other.inputBorderFocused, t),
      secondaryButtonBg:
          Color.lerp(secondaryButtonBg, other.secondaryButtonBg, t),
      secondaryButtonText:
          Color.lerp(secondaryButtonText, other.secondaryButtonText, t),
      blobPurple: Color.lerp(blobPurple, other.blobPurple, t),
      blobMint: Color.lerp(blobMint, other.blobMint, t),
      illustrationCircle:
          Color.lerp(illustrationCircle, other.illustrationCircle, t),
      termsLink: Color.lerp(termsLink, other.termsLink, t),
      indicatorInactive:
          Color.lerp(indicatorInactive, other.indicatorInactive, t),
      buttonText: Color.lerp(buttonText, other.buttonText, t),
      tabBarBg: Color.lerp(tabBarBg, other.tabBarBg, t),
      tabTextActive: Color.lerp(tabTextActive, other.tabTextActive, t),
      tabTextInactive: Color.lerp(tabTextInactive, other.tabTextInactive, t),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'SFProRounded';

  // ---------------------------------------------------------------------------
  // Raw color palette — single source of truth (from Figma)
  // ---------------------------------------------------------------------------

  static const Color _cyan = Color(0xFF19C3E0); // Brand primary / button bg
  static const Color _darkText = Color(0xFF1C1C1C); // Main body text (light)
  static const Color _lightText = Color(0xFFE3E3E3); // Main body text (dark)
  static const Color _bgLight = Color(0xFFFEFEFE);
  static const Color _bgDark = Color(0xFF1C1C1C);
  static const Color _teal = Color(0xFF0F7586); // preText / secondary btn text
  static const Color _gray = Color(0xFF757575); // Hint / inactive
  static const Color _outlineLight = Color(0xFFD8D8D8);
  static const Color _outlineDark = Color(0xFF343434);
  static const Color _inputBorder = Color(0xFFBABABA); // Figma input border
  static const Color _errorLight = Color(0xFFC33E36);
  static const Color _errorDark = Color(0xFFCC4D47);
  static const Color _errorBgLight = Color(0xFFFFF2F1);
  static const Color _errorBgDark = Color(0xFF141414);
  static const Color _surfaceFocusedLight = Color(0xFFE8F9FC);
  static const Color _surfaceFocusedDark = Color(0xFF00232A);
  static const Color _headerLight = Color(0xFFB8ECF5); // secondary / illus circle
  static const Color _headerDark = Color(0xFF0D515D);
  static const Color _tabLight = Color(0xFFF1F1F1);
  static const Color _navSelected = Color(0xFF2DB6A3);
  static const Color _navUnselected = Color(0xFF9E9E9E);
  static const Color _link = Color(0xFF2675ED);

  // Figma-specific extras
  static const Color _purple = Color(0xFFE083FF); // decorative blob
  static const Color _mint = Color(0xFF67FFAB); // decorative blob
  static const Color _buttonText = Color(0xFF0C0C0C); // text on primary button
  static const Color _termsLink = Color(0xFF1367E6); // T&C link
  static const Color _indicatorInactive = Color(0xFFD8D8D8);
  static const Color _white = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Named accessors (kept for backward-compat references in old code)
  // ---------------------------------------------------------------------------
  static const Color buttonLightColor = _cyan;
  static const Color buttonDarkColor = _cyan;
  static const Color bgLightColor = _bgLight;
  static const Color bgDarkColor = _bgDark;
  static const Color textLightColor = _darkText;
  static const Color textDarkColor = _lightText;
  static const Color textFieldTextLightColor = _teal;
  static const Color textFieldTextDarkColor = _lightText;
  static const Color outlineLightColor = _outlineLight;
  static const Color outlineDarkColor = _outlineDark;
  static const Color outlineFocusedLightColor = _cyan;
  static const Color outlineFocusedDarkColor = _cyan;
  static const Color errorTextFieldLightColor = _errorBgLight;
  static const Color errorTextFieldDarkColor = _errorBgDark;
  static const Color errorLightColor = _errorLight;
  static const Color errorDarkColor = _errorDark;
  static const Color grayTextColor = _gray;
  static const Color grayTextDarkColor = _gray;
  static const Color tabLightColor = _tabLight;
  static const Color preTextColor = _teal;
  static const Color surfaceFocusedLightColor = _surfaceFocusedLight;
  static const Color surfaceFocusedDarkColor = _surfaceFocusedDark;
  static const Color linkColor = _link;
  static const Color navBgColor = _bgLight;
  static const Color navSelectedColor = _navSelected;
  static const Color navUnselectedColor = _navUnselected;
  static const Color headerLightColor = _headerLight;
  static const Color headerDarkColor = _headerDark;

  // ---------------------------------------------------------------------------
  // Design spacing / sizing constants (use these instead of raw doubles)
  // ---------------------------------------------------------------------------

  /// Standard horizontal page padding — user requested 16dp
  static const double hPadding = 16.0;
  /// Input field height — Figma ~52dp
  static const double inputHeight = 52.0;
  /// Primary button height — Figma ~52dp
  static const double buttonHeight = 52.0;
  /// Default border radius for inputs and buttons
  static const double inputRadius = 16.0;
  static const double buttonRadius = 18.0;
  /// Input border width (unfocused / focused)
  static const double borderWidthDefault = 1.0;
  static const double borderWidthFocused = 2.0;
  /// Active page-indicator dot diameter
  static const double indicatorActive = 14.0;
  /// Inactive page-indicator dot diameter
  static const double indicatorInactive = 10.0;
  /// Spacing between indicator dots
  static const double indicatorSpacing = 10.0;
  static double responsiveHeight(BuildContext context, double standardValue) {
    final height = MediaQuery.of(context).size.height;
    if (height < 700) {
      return standardValue * 0.8;
    } else if (height < 750) {
      return standardValue * 0.9;
    }
    return standardValue;
  }

  static double responsiveInputHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 700) {
      return 46.0;
    } else if (height < 750) {
      return 48.0;
    }
    return 52.0;
  }

  // ---------------------------------------------------------------------------
  // VitalUpColors theme extensions
  // ---------------------------------------------------------------------------

  static const VitalUpColors lightCustomColors = VitalUpColors(
    header: _headerLight,
    button: _cyan,
    textFieldText: _teal,
    outlineFocused: _cyan,
    errorTextField: _errorBgLight,
    grayText: _gray,
    tab: _tabLight,
    preText: _teal,
    surfaceFocused: _surfaceFocusedLight,
    link: _link,
    navBg: _bgLight,
    navSelected: _navSelected,
    navUnselected: _navUnselected,
    inputBorder: _inputBorder,
    inputBorderFocused: _cyan,
    secondaryButtonBg: _bgLight,
    secondaryButtonText: _teal,
    blobPurple: _purple,
    blobMint: _mint,
    illustrationCircle: _headerLight,
    termsLink: _termsLink,
    indicatorInactive: _indicatorInactive,
    buttonText: _buttonText,
    tabBarBg: Color(0xFFEBEBEB), // Figma tab container: light gray
    tabTextActive: _white,
    tabTextInactive: _gray,
  );

  static const VitalUpColors darkCustomColors = VitalUpColors(
    header: _headerDark,
    button: _cyan,
    textFieldText: _lightText,
    outlineFocused: _cyan,
    errorTextField: _errorBgDark,
    grayText: _gray,
    tab: _bgDark,
    preText: _teal,
    surfaceFocused: _surfaceFocusedDark,
    link: _link,
    navBg: _bgDark,
    navSelected: _navSelected,
    navUnselected: _navUnselected,
    inputBorder: _outlineDark,
    inputBorderFocused: _cyan,
    secondaryButtonBg: _bgDark,
    secondaryButtonText: _teal,
    blobPurple: _purple,
    blobMint: _mint,
    illustrationCircle: _headerDark,
    termsLink: _termsLink,
    indicatorInactive: _outlineDark,
    buttonText: _buttonText,
    tabBarBg: _outlineDark,
    tabTextActive: _white,
    tabTextInactive: _gray,
  );

  // ---------------------------------------------------------------------------
  // Typography — all sizes taken from Figma spec
  // ---------------------------------------------------------------------------

  static const TextTheme _textTheme = TextTheme(
    // Page headers (Figma: 36sp w600)
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 36.0,
      height: 1.1,
      letterSpacing: 0.0,
    ),
    // Section headings
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 26.0,
      height: 1.2,
      letterSpacing: 0.0,
    ),
    // Card titles
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 20.0,
      height: 1.2,
      letterSpacing: 0.0,
    ),
    // Large title (kept for compat)
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 30.0,
      height: 0.93,
      letterSpacing: 0.0,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 20.0,
      height: 1.4,
      letterSpacing: 0.0,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 16.0,
      height: 1.3,
      letterSpacing: 0.0,
    ),
    // Body text
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 16.0,
      height: 1.5,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 15.0,
      height: 1.47,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 13.0,
      height: 1.23,
      letterSpacing: 0.25,
    ),
    // Labels / buttons (Figma button: 16sp w500)
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 16.0,
      height: 1.25,
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 14.0,
      height: 1.3,
      letterSpacing: 0.25,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 12.0,
      height: 1.33,
      letterSpacing: 0.5,
    ),
  );

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _cyan,
      scaffoldBackgroundColor: _bgLight,
      extensions: const [lightCustomColors],
      colorScheme: const ColorScheme.light(
        primary: _cyan,
        secondary: _headerLight,
        tertiary: _tabLight,
        surface: _errorBgLight,
        onPrimary: _white,
        onSecondary: _white,
        onTertiary: _gray,
        onSurface: _darkText,
        outline: _outlineLight,
        error: _errorLight,
        surfaceContainerHighest: Color(0x1A1C1C1C),
        surfaceBright: _surfaceFocusedLight,
      ),
      textTheme: _textTheme.apply(
        bodyColor: _darkText,
        displayColor: _darkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bgLight,
        foregroundColor: _darkText,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _bgLight,
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _cyan,
      scaffoldBackgroundColor: _bgDark,
      extensions: const [darkCustomColors],
      colorScheme: const ColorScheme.dark(
        primary: _cyan,
        secondary: _headerDark,
        tertiary: Colors.transparent,
        surface: _errorBgDark,
        onPrimary: _white,
        onSecondary: _white,
        onTertiary: _gray,
        onSurface: _lightText,
        outline: _outlineDark,
        error: _errorDark,
        surfaceContainerHighest: Color(0x1AFEFEFE),
        surfaceBright: _surfaceFocusedDark,
      ),
      textTheme: _textTheme.apply(
        bodyColor: _lightText,
        displayColor: _lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bgDark,
        foregroundColor: _lightText,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _bgDark,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Subtle entry slide from right to left
    final slideIn = Tween<Offset>(
      begin: const Offset(0.12, 0.0), // Subtle movement for premium look
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Primary fade in
    final fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    // Subtle exit slide to the left when another screen is pushed
    final slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.06, 0.0), // Parallax effect
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Fade out when covered
    final fadeOut = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    return SlideTransition(
      position: slideIn,
      child: FadeTransition(
        opacity: fadeIn,
        child: SlideTransition(
          position: slideOut,
          child: FadeTransition(
            opacity: fadeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}
