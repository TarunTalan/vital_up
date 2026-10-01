import 'package:flutter/material.dart';
import 'package:vital_up/core/router/app_page_transitions.dart';
import 'package:vital_up/core/theme/app_colors.dart';
import 'package:vital_up/core/theme/app_dimens.dart';
import 'package:vital_up/core/theme/app_text_styles.dart';

export 'package:vital_up/core/theme/app_colors.dart';
export 'package:vital_up/core/theme/app_dimens.dart';
export 'package:vital_up/core/theme/app_text_styles.dart';
export 'package:vital_up/core/theme/theme_context.dart';

/// Custom theme extension for VitalUp brand colours that are not part of the
/// standard Material [ColorScheme]. Access with `context.vColors`.
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
  final Color? inputBorder;
  final Color? inputBorderFocused;
  final Color? secondaryButtonBg;
  final Color? secondaryButtonText;
  final Color? blobPurple;
  final Color? blobMint;
  final Color? illustrationCircle;
  final Color? termsLink;
  final Color? indicatorInactive;
  final Color? buttonText;
  final Color? tabBarBg;
  final Color? tabTextActive;
  final Color? tabTextInactive;

  // --- Figma glass / status tokens ---
  /// Glass card & input fill — Figma rgba(186,186,186,0.13).
  final Color? glassFill;
  /// Glass card & input border — Figma rgba(186,186,186,0.27).
  final Color? glassBorder;
  /// Divider — Figma #BABABA @ 30%.
  final Color? divider;
  /// Progress-bar track.
  final Color? track;
  /// Cyan tinted fill (filled input, header action button).
  final Color? primaryFill;
  /// Cyan icon-badge background.
  final Color? primaryTint;
  /// Cyan tinted border (header action button).
  final Color? primaryBorder;
  /// Secondary button outline — Figma #B9B9B9.
  final Color? secondaryButtonBorder;
  /// Back button fill.
  final Color? backButtonFill;
  /// Elevated opaque surface (bottom sheets, dialogs, nav bar).
  final Color? surfaceElevated;
  /// Error input fill — Figma rgba(226,75,74,0.13).
  final Color? errorFill;
  final Color? success;
  final Color? successTint;
  final Color? warning;
  final Color? warningTint;
  final Color? info;
  /// Hairline outline (toast/info) — Figma #D8D8D8.
  final Color? hairline;

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
    required this.glassFill,
    required this.glassBorder,
    required this.divider,
    required this.track,
    required this.primaryFill,
    required this.primaryTint,
    required this.primaryBorder,
    required this.secondaryButtonBorder,
    required this.backButtonFill,
    required this.surfaceElevated,
    required this.errorFill,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.info,
    required this.hairline,
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
    Color? glassFill,
    Color? glassBorder,
    Color? divider,
    Color? track,
    Color? primaryFill,
    Color? primaryTint,
    Color? primaryBorder,
    Color? secondaryButtonBorder,
    Color? backButtonFill,
    Color? surfaceElevated,
    Color? errorFill,
    Color? success,
    Color? successTint,
    Color? warning,
    Color? warningTint,
    Color? info,
    Color? hairline,
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
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      divider: divider ?? this.divider,
      track: track ?? this.track,
      primaryFill: primaryFill ?? this.primaryFill,
      primaryTint: primaryTint ?? this.primaryTint,
      primaryBorder: primaryBorder ?? this.primaryBorder,
      secondaryButtonBorder:
          secondaryButtonBorder ?? this.secondaryButtonBorder,
      backButtonFill: backButtonFill ?? this.backButtonFill,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      errorFill: errorFill ?? this.errorFill,
      success: success ?? this.success,
      successTint: successTint ?? this.successTint,
      warning: warning ?? this.warning,
      warningTint: warningTint ?? this.warningTint,
      info: info ?? this.info,
      hairline: hairline ?? this.hairline,
    );
  }

  @override
  VitalUpColors lerp(ThemeExtension<VitalUpColors>? other, double t) {
    if (other is! VitalUpColors) return this;
    Color? l(Color? a, Color? b) => Color.lerp(a, b, t);
    return VitalUpColors(
      header: l(header, other.header),
      button: l(button, other.button),
      textFieldText: l(textFieldText, other.textFieldText),
      outlineFocused: l(outlineFocused, other.outlineFocused),
      errorTextField: l(errorTextField, other.errorTextField),
      grayText: l(grayText, other.grayText),
      tab: l(tab, other.tab),
      preText: l(preText, other.preText),
      surfaceFocused: l(surfaceFocused, other.surfaceFocused),
      link: l(link, other.link),
      navBg: l(navBg, other.navBg),
      navSelected: l(navSelected, other.navSelected),
      navUnselected: l(navUnselected, other.navUnselected),
      inputBorder: l(inputBorder, other.inputBorder),
      inputBorderFocused: l(inputBorderFocused, other.inputBorderFocused),
      secondaryButtonBg: l(secondaryButtonBg, other.secondaryButtonBg),
      secondaryButtonText: l(secondaryButtonText, other.secondaryButtonText),
      blobPurple: l(blobPurple, other.blobPurple),
      blobMint: l(blobMint, other.blobMint),
      illustrationCircle: l(illustrationCircle, other.illustrationCircle),
      termsLink: l(termsLink, other.termsLink),
      indicatorInactive: l(indicatorInactive, other.indicatorInactive),
      buttonText: l(buttonText, other.buttonText),
      tabBarBg: l(tabBarBg, other.tabBarBg),
      tabTextActive: l(tabTextActive, other.tabTextActive),
      tabTextInactive: l(tabTextInactive, other.tabTextInactive),
      glassFill: l(glassFill, other.glassFill),
      glassBorder: l(glassBorder, other.glassBorder),
      divider: l(divider, other.divider),
      track: l(track, other.track),
      primaryFill: l(primaryFill, other.primaryFill),
      primaryTint: l(primaryTint, other.primaryTint),
      primaryBorder: l(primaryBorder, other.primaryBorder),
      secondaryButtonBorder:
          l(secondaryButtonBorder, other.secondaryButtonBorder),
      backButtonFill: l(backButtonFill, other.backButtonFill),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      errorFill: l(errorFill, other.errorFill),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      warning: l(warning, other.warning),
      warningTint: l(warningTint, other.warningTint),
      info: l(info, other.info),
      hairline: l(hairline, other.hairline),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = AppTextStyles.fontFamily;

  // ---------------------------------------------------------------------------
  // Named accessors (kept for backward-compat references in old code)
  // ---------------------------------------------------------------------------
  static const Color buttonLightColor = AppColors.primary;
  static const Color buttonDarkColor = AppColors.primary;
  static const Color bgLightColor = AppColors.lighter;
  static const Color bgDarkColor = AppColors.surfaceDark;
  static const Color textLightColor = AppColors.darker;
  static const Color textDarkColor = AppColors.lightText;
  static const Color errorLightColor = AppColors.error;
  static const Color errorDarkColor = AppColors.errorDark;
  static const Color grayTextColor = AppColors.greyText;
  static const Color preTextColor = AppColors.teal;
  static const Color linkColor = AppColors.link;

  // ---------------------------------------------------------------------------
  // Sizing aliases → AppDimens (prefer AppDimens in new code)
  // ---------------------------------------------------------------------------
  static const double hPadding = AppDimens.gutter;
  static const double inputHeight = AppDimens.inputHeight;
  static const double buttonHeight = AppDimens.buttonHeight;
  static const double inputRadius = AppDimens.radiusInput;
  static const double buttonRadius = AppDimens.radiusButton;
  static const double cardRadius = AppDimens.radiusCard;
  static const double borderWidthDefault = AppDimens.borderThin;
  static const double borderWidthFocused = AppDimens.borderThick;
  static const double indicatorActive = 14.0;
  static const double indicatorInactive = 10.0;
  static const double indicatorSpacing = 10.0;

  static double responsiveHeight(BuildContext context, double standardValue) {
    final height = MediaQuery.sizeOf(context).height;
    if (height < 700) return standardValue * 0.8;
    if (height < 750) return standardValue * 0.9;
    return standardValue;
  }

  static double responsiveInputHeight(BuildContext context) =>
      responsiveHeight(context, AppDimens.inputHeight).clamp(48.0, 56.0);

  // ---------------------------------------------------------------------------
  // VitalUpColors theme extensions
  // ---------------------------------------------------------------------------

  static const VitalUpColors lightCustomColors = VitalUpColors(
    header: AppColors.highlight,
    button: AppColors.primary,
    textFieldText: AppColors.teal,
    outlineFocused: AppColors.primary,
    errorTextField: AppColors.errorFill,
    grayText: AppColors.greyText,
    tab: Color(0xFFF1F1F1),
    preText: AppColors.teal,
    surfaceFocused: AppColors.primaryFill,
    link: AppColors.link,
    navBg: AppColors.lighter,
    navSelected: AppColors.darker,
    navUnselected: AppColors.greyText,
    inputBorder: AppColors.glassBorder,
    inputBorderFocused: AppColors.primary,
    secondaryButtonBg: Colors.transparent,
    secondaryButtonText: AppColors.teal,
    blobPurple: AppColors.blobPurple,
    blobMint: AppColors.blobMint,
    illustrationCircle: AppColors.highlight,
    termsLink: AppColors.termsLink,
    indicatorInactive: AppColors.indicatorInactive,
    buttonText: AppColors.buttonText,
    tabBarBg: AppColors.glassFill,
    tabTextActive: AppColors.darker,
    tabTextInactive: AppColors.darker,
    glassFill: AppColors.glassFill,
    glassBorder: AppColors.glassBorder,
    divider: AppColors.divider,
    track: AppColors.track,
    primaryFill: AppColors.primaryFill,
    primaryTint: AppColors.primaryTint,
    primaryBorder: AppColors.primaryBorder,
    secondaryButtonBorder: AppColors.secondaryBorder,
    backButtonFill: AppColors.backButtonFill,
    surfaceElevated: AppColors.lighter,
    errorFill: AppColors.errorFill,
    success: AppColors.success,
    successTint: AppColors.successTint,
    warning: AppColors.warning,
    warningTint: AppColors.warningTint,
    info: AppColors.info,
    hairline: AppColors.outline,
  );

  static const VitalUpColors darkCustomColors = VitalUpColors(
    header: AppColors.highlightDark,
    button: AppColors.primary,
    textFieldText: AppColors.lightText,
    outlineFocused: AppColors.primary,
    errorTextField: AppColors.errorFill,
    grayText: AppColors.greyText,
    tab: AppColors.surfaceDark,
    preText: AppColors.primary,
    surfaceFocused: AppColors.primaryFill,
    link: AppColors.link,
    navBg: AppColors.surfaceDarkElevated,
    navSelected: AppColors.lightText,
    navUnselected: AppColors.greyText,
    inputBorder: AppColors.glassBorderDark,
    inputBorderFocused: AppColors.primary,
    secondaryButtonBg: Colors.transparent,
    secondaryButtonText: AppColors.primary,
    blobPurple: AppColors.blobPurple,
    blobMint: AppColors.blobMint,
    illustrationCircle: AppColors.highlightDark,
    termsLink: AppColors.termsLink,
    indicatorInactive: AppColors.outlineDark,
    buttonText: AppColors.buttonText,
    tabBarBg: AppColors.glassFillDark,
    tabTextActive: AppColors.darker,
    tabTextInactive: AppColors.lightText,
    glassFill: AppColors.glassFillDark,
    glassBorder: AppColors.glassBorderDark,
    divider: AppColors.dividerDark,
    track: AppColors.trackDark,
    primaryFill: AppColors.primaryFill,
    primaryTint: AppColors.primaryTint,
    primaryBorder: AppColors.primaryBorder,
    secondaryButtonBorder: AppColors.outlineDark,
    backButtonFill: AppColors.backButtonFillDark,
    surfaceElevated: AppColors.surfaceDarkElevated,
    errorFill: AppColors.errorFill,
    success: AppColors.success,
    successTint: AppColors.successTint,
    warning: AppColors.warning,
    warningTint: AppColors.warningTint,
    info: AppColors.info,
    hairline: AppColors.outlineDark,
  );

  // ---------------------------------------------------------------------------
  // Themes
  // ---------------------------------------------------------------------------

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        custom: lightCustomColors,
        scheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.buttonText,
          primaryContainer: AppColors.primaryTint,
          onPrimaryContainer: AppColors.teal,
          secondary: AppColors.highlight,
          onSecondary: AppColors.darker,
          tertiary: Color(0xFFF1F1F1),
          onTertiary: AppColors.greyText,
          surface: AppColors.lighter,
          onSurface: AppColors.darker,
          onSurfaceVariant: AppColors.greyText,
          surfaceContainerLowest: AppColors.white,
          surfaceContainerLow: Color(0xFFF8F8F8),
          surfaceContainer: Color(0xFFF3F3F3),
          surfaceContainerHigh: Color(0xFFEDEDED),
          surfaceContainerHighest: Color(0x1A1C1C1C),
          surfaceBright: AppColors.primaryFill,
          outline: AppColors.outline,
          outlineVariant: AppColors.glassBorder,
          error: AppColors.error,
          onError: AppColors.white,
          errorContainer: AppColors.errorFill,
          onErrorContainer: AppColors.error,
          shadow: AppColors.black,
          inverseSurface: AppColors.darker,
          onInverseSurface: AppColors.lighter,
        ),
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        custom: darkCustomColors,
        scheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.buttonText,
          primaryContainer: AppColors.primaryTint,
          onPrimaryContainer: AppColors.primary,
          secondary: AppColors.highlightDark,
          onSecondary: AppColors.lightText,
          tertiary: Colors.transparent,
          onTertiary: AppColors.greyText,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.lightText,
          onSurfaceVariant: Color(0xFF9E9E9E),
          surfaceContainerLowest: Color(0xFF141414),
          surfaceContainerLow: Color(0xFF202020),
          surfaceContainer: Color(0xFF242424),
          surfaceContainerHigh: AppColors.surfaceDarkElevated,
          surfaceContainerHighest: Color(0x1AFEFEFE),
          surfaceBright: AppColors.primaryFill,
          outline: AppColors.outlineDark,
          outlineVariant: AppColors.glassBorderDark,
          error: AppColors.errorDark,
          onError: AppColors.white,
          errorContainer: AppColors.errorFill,
          onErrorContainer: AppColors.errorDark,
          shadow: AppColors.black,
          inverseSurface: AppColors.lightText,
          onInverseSurface: AppColors.darker,
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required VitalUpColors custom,
    required ColorScheme scheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppTextStyles.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusButton),
    );
    const buttonMinSize = Size(64, AppDimens.buttonHeight);

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTextStyles.fontFamily,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      extensions: [custom],
      textTheme: textTheme,
      dividerColor: custom.divider,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.displayMedium,
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppDimens.iconLg),
      ),
      cardTheme: CardThemeData(
        color: custom.glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: BorderSide(color: custom.glassBorder!, width: AppDimens.borderThin),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: custom.buttonText,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
          disabledForegroundColor: custom.buttonText!.withValues(alpha: 0.6),
          minimumSize: buttonMinSize,
          padding: AppDimens.buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: custom.buttonText,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
          minimumSize: buttonMinSize,
          padding: AppDimens.buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: custom.secondaryButtonText,
          minimumSize: buttonMinSize,
          padding: AppDimens.buttonPadding,
          shape: buttonShape,
          side: BorderSide(
            color: custom.secondaryButtonBorder!,
            width: AppDimens.borderThin,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: custom.secondaryButtonText,
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: custom.glassFill,
        contentPadding: AppDimens.inputPadding,
        hintStyle: textTheme.bodyMedium?.copyWith(color: custom.grayText),
        labelStyle: textTheme.titleSmall,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: inputBorder(custom.glassBorder!, AppDimens.borderThin),
        enabledBorder: inputBorder(custom.glassBorder!, AppDimens.borderThin),
        focusedBorder: inputBorder(scheme.primary, AppDimens.borderThick),
        errorBorder: inputBorder(scheme.error, AppDimens.borderThick),
        focusedErrorBorder: inputBorder(scheme.error, AppDimens.borderThick),
        disabledBorder: inputBorder(custom.glassBorder!, AppDimens.borderThin),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: custom.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: custom.surfaceElevated,
        modalBackgroundColor: custom.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        dragHandleColor: custom.divider,
        dragHandleSize: const Size(
          AppDimens.sheetHandleWidth,
          AppDimens.sheetHandleHeight,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusSheet),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: custom.glassFill,
        selectedColor: scheme.primary,
        side: BorderSide(color: custom.glassBorder!),
        labelStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: custom.divider,
        thickness: AppDimens.borderThin,
        space: AppDimens.borderThin,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: custom.track,
        circularTrackColor: custom.track,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null),
        checkColor: WidgetStatePropertyAll(custom.buttonText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXs),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: custom.track,
        thumbColor: scheme.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: custom.grayText),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.space16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: custom.navBg,
        indicatorColor: custom.primaryTint,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkElevated : AppColors.darker,
          borderRadius: BorderRadius.circular(AppDimens.radiusToast),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.lighter),
      ),
      pageTransitionsTheme: appPageTransitionsTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100), // Pill shape for modern toast look
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
