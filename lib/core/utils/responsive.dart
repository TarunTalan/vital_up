import 'dart:math' as math;

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
  /// Tablets get slightly larger text. Small phones keep the user's size:
  /// shrinking below their accessibility setting would make text unreadable.
  double get textFactor => isTablet ? 1.1 : 1.0;

  /// How much body text is enlarged (1.0 = default, 2.0 = largest).
  double get textScale =>
      MediaQuery.textScalerOf(this).scale(AppTextScaler.reference) /
      AppTextScaler.reference;

  /// [size] (a box that holds a line of text: chip, tile, field) grown with
  /// body text. Never smaller than [size]: icons and padding don't shrink.
  double textScaled(double size) => size * math.max(1.0, textScale);

  /// Large text: dense rows (several columns, half-width tiles) should
  /// reflow into fewer, wider columns instead of cutting text off.
  bool get isLargeText => textScale >= AppTextScaler.largeTextScale;
}

/// Grows text with the system setting the way Android 14+ does: body sizes
/// (up to [reference]) by the full factor, larger sizes (headings, metrics)
/// by less, so a 36 heading doesn't double and push everything off screen.
/// Applied to every platform and Android version, so all look the same.
class AppTextScaler extends TextScaler {
  /// Body text size that gets the full factor.
  static const double reference = 14;

  /// From here on, dense layouts reflow ([Responsive.isLargeText]).
  /// 1.2: the phone's 115% step keeps the default layout; 125% and up
  /// (where four columns and half tiles start cutting text) reflow.
  static const double largeTextScale = 1.2;

  final double factor;

  const AppTextScaler(this.factor);

  @override
  double scale(double fontSize) {
    if (factor <= 1 || fontSize <= reference) return fontSize * factor;
    final damping = math.pow(reference / fontSize, 0.75).toDouble();
    return fontSize * (1 + (factor - 1) * damping);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
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
/// text scale is respected up to [maxSystemScale], and tablets get a
/// little larger. Never smaller than the user's
/// own setting. Large styles grow less than body text ([AppTextScaler]).
/// Every `Text` in the app inherits this.
class ResponsiveTextScale extends StatelessWidget {
  final Widget child;
  static const double minSystemScale = 0.85;

  /// 150%: the common cap for dense, data-heavy apps. Body text still grows
  /// half again, while dashboards, tiles and charts stay readable (Android
  /// goes to 200%, where four-figure rows and half tiles can't fit).
  static const double maxSystemScale = 1.5;

  const ResponsiveTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final system =
        mq.textScaler
            .clamp(
              minScaleFactor: minSystemScale,
              maxScaleFactor: maxSystemScale,
            )
            .scale(AppTextScaler.reference) /
        AppTextScaler.reference;
    return MediaQuery(
      data: mq.copyWith(
        textScaler: AppTextScaler(
          (system * context.textFactor).clamp(system, maxSystemScale),
        ),
      ),
      child: child,
    );
  }
}
