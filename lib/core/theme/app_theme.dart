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
    );
  }

  @override
  VitalUpColors lerp(ThemeExtension<VitalUpColors>? other, double t) {
    if (other is! VitalUpColors) {
      return this;
    }
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
    );
  }
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'SFProRounded';

  // Base Kotlin Colors mapped to Flutter equivalents
  static const Color headerLightColor = Color(0xFFB8ECF5);
  static const Color headerDarkColor = Color(0xFF0D515D);

  static const Color buttonLightColor = Color(0xFF19C3E0);
  static const Color buttonDarkColor = buttonLightColor;

  static const Color bgLightColor = Color(0xFFFEFEFE);
  static const Color bgDarkColor = Color(0xFF1C1C1C);

  static const Color textLightColor = Color(0xFF1C1C1C);
  static const Color textDarkColor = Color(0xFFE3E3E3);

  static const Color textFieldTextLightColor = Color(0xFF0F7586);
  static const Color textFieldTextDarkColor = Color(0xFFE3E3E3);

  static const Color outlineLightColor = Color(0xFFD8D8D8);
  static const Color outlineDarkColor = Color(0xFF343434);

  static const Color outlineFocusedLightColor = buttonLightColor;
  static const Color outlineFocusedDarkColor = outlineFocusedLightColor;

  static const Color errorTextFieldLightColor = Color(0xFFFFF2F1);
  static const Color errorTextFieldDarkColor = Color(0xFF141414);

  static const Color errorLightColor = Color(0xFFC33E36);
  static const Color errorDarkColor = Color(0xFFCC4D47);

  static const Color grayTextColor = Color(0xFF757575);
  static const Color grayTextDarkColor = Color(0xFF757575);

  static const Color tabLightColor = Color(0xFFF1F1F1);

  static const Color preTextColor = Color(0xFF0F7586);
  static const Color surfaceFocusedLightColor = Color(0xFFE8F9FC);
  static const Color surfaceFocusedDarkColor = Color(0xFF00232A);
  static const Color linkColor = Color(0xFF2675ED);

  static const Color navBgColor = Color(0xFFFEFEFE);
  static const Color navSelectedColor = Color(0xFF2DB6A3);
  static const Color navUnselectedColor = Color(0xFF9E9E9E);

  // Custom Colors Theme Extensions
  static const VitalUpColors lightCustomColors = VitalUpColors(
    header: headerLightColor,
    button: buttonLightColor,
    textFieldText: textFieldTextLightColor,
    outlineFocused: outlineFocusedLightColor,
    errorTextField: errorTextFieldLightColor,
    grayText: grayTextColor,
    tab: tabLightColor,
    preText: preTextColor,
    surfaceFocused: surfaceFocusedLightColor,
    link: linkColor,
    navBg: navBgColor,
    navSelected: navSelectedColor,
    navUnselected: navUnselectedColor,
  );

  static const VitalUpColors darkCustomColors = VitalUpColors(
    header: headerDarkColor,
    button: buttonDarkColor,
    textFieldText: textFieldTextDarkColor,
    outlineFocused: outlineFocusedDarkColor,
    errorTextField: errorTextFieldDarkColor,
    grayText: grayTextDarkColor,
    tab: bgDarkColor, // Fallback for unspecified dark tab color
    preText: preTextColor,
    surfaceFocused: surfaceFocusedDarkColor,
    link: linkColor,
    navBg: bgDarkColor, // Fallback dark navigation background
    navSelected: navSelectedColor,
    navUnselected: navUnselectedColor,
  );

  // Typography Definition
  static const TextTheme _textTheme = TextTheme(
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400, // Normal
      fontSize: 16.0,
      height: 1.5, // 24.0 / 16.0
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400, // Normal
      fontSize: 15.0,
      height: 1.47, // 22.0 / 15.0
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400, // Normal
      fontSize: 13.0,
      height: 1.23, // 16.0 / 13.0
      letterSpacing: 0.25,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600, // SemiBold
      fontSize: 30.0,
      height: 0.93, // 28.0 / 30.0
      letterSpacing: 0.0,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500, // Medium
      fontSize: 14.0,
      height: 1.14, // 16.0 / 14.0
      letterSpacing: 0.5,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400, // Normal
      fontSize: 13.0,
      height: 1.23, // 16.0 / 13.0
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500, // Medium
      fontSize: 11.0,
      height: 1.45, // 16.0 / 11.0
      letterSpacing: 0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400, // Normal
      fontSize: 14.0,
      height: 1.14, // 16.0 / 14.0
      letterSpacing: 0.5,
    ),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: buttonLightColor,
      scaffoldBackgroundColor: bgLightColor,
      extensions: const [lightCustomColors],
      colorScheme: const ColorScheme.light(
        primary: buttonLightColor,
        secondary: headerLightColor,
        tertiary: tabLightColor,
        background: bgLightColor,
        surface: errorTextFieldLightColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: grayTextColor,
        onBackground: textLightColor,
        onSurface: textFieldTextLightColor,
        outline: outlineLightColor,
        error: errorLightColor,
        surfaceVariant: Color(0x1A1C1C1C), // Color(rgb(28, 28, 28)).copy(alpha = 0.1f)
        surfaceBright: surfaceFocusedLightColor,
      ),
      textTheme: _textTheme.apply(
        bodyColor: textLightColor,
        displayColor: textLightColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLightColor,
        foregroundColor: textLightColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: bgLightColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: buttonDarkColor,
      scaffoldBackgroundColor: bgDarkColor,
      extensions: const [darkCustomColors],
      colorScheme: const ColorScheme.dark(
        primary: buttonDarkColor,
        secondary: headerDarkColor,
        tertiary: Colors.transparent, // Color.Unspecified
        background: bgDarkColor,
        surface: errorTextFieldDarkColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: grayTextDarkColor,
        onBackground: textDarkColor,
        onSurface: textFieldTextDarkColor,
        outline: outlineDarkColor,
        error: errorDarkColor,
        surfaceVariant: Color(0x1AFEFEFE), // Color(rgb(254, 254, 254)).copy(alpha = 0.1f)
        surfaceBright: surfaceFocusedDarkColor,
      ),
      textTheme: _textTheme.apply(
        bodyColor: textDarkColor,
        displayColor: textDarkColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDarkColor,
        foregroundColor: textDarkColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: bgDarkColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
