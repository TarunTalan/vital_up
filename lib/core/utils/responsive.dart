import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_dimens.dart';

/// Screen-size helpers. All UI sizing that should adapt to the device goes
/// through these instead of raw `MediaQuery` math in widgets.
///
/// Usage:
/// ```dart
/// SizedBox(height: context.h(AppDimens.space24))
/// Padding(padding: context.pagePadding)
/// if (context.isTablet) ...
/// ```
extension Responsive on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get safePadding => MediaQuery.paddingOf(this);

  bool get isTablet => screenSize.shortestSide >= AppDimens.tabletBreakpoint;
  bool get isSmallPhone => screenWidth < AppDimens.smallPhoneBreakpoint;

  /// Short screens (e.g. iPhone SE / small Androids).
  bool get isShortScreen => screenHeight < 700;

  /// Width scale relative to the 412dp Figma frame, clamped so layouts never
  /// get tiny on small phones or huge on tablets.
  double get widthScale {
    final width = isTablet
        ? AppDimens.maxContentWidth
        : screenWidth.clamp(0.0, AppDimens.maxContentWidth);
    return (width / AppDimens.designWidth).clamp(0.85, 1.15);
  }

  /// Height scale relative to the 917dp Figma frame, clamped.
  double get heightScale =>
      (screenHeight / AppDimens.designHeight).clamp(0.8, 1.15);

  /// Scale a horizontal / size value from the Figma frame.
  double w(double value) => value * widthScale;

  /// Scale a vertical value from the Figma frame.
  double h(double value) => value * heightScale;

  /// Fraction of the screen height (e.g. illustrations).
  double hFraction(double fraction) => screenHeight * fraction;

  /// Horizontal page gutter.
  double get gutter => isTablet ? AppDimens.gutterTablet : AppDimens.gutter;

  /// Standard page padding (horizontal gutter only).
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: gutter);

  /// Responsive text factor applied app-wide (see `main.dart`).
  double get textFactor {
    if (isTablet) return 1.1;
    if (isSmallPhone) return 0.9;
    return 1.0;
  }
}

/// Centres [child] and caps its width at [AppDimens.maxContentWidth] so pages
/// don't stretch edge-to-edge on tablets. No-op on phones.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppDimens.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Applies app-wide responsive text scaling: the device's accessibility
/// text scale is respected but clamped (so layouts don't break), then
/// multiplied by a screen-size factor (smaller on small phones, larger on
/// tablets). Every `Text` in the app inherits this.
class ResponsiveTextScale extends StatelessWidget {
  final Widget child;
  static const double minSystemScale = 0.85;
  static const double maxSystemScale = 1.1;

  const ResponsiveTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final system = mq.textScaler
        .clamp(minScaleFactor: minSystemScale, maxScaleFactor: maxSystemScale)
        .scale(14) /
        14;
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(system * context.textFactor),
      ),
      child: child,
    );
  }
}
