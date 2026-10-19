import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:vital_up/core/theme/app_text_styles.dart';
import 'package:vital_up/core/widgets/measured_layout_builder.dart';

/// Text that shrinks to fit its width, but never below a readable size:
/// past that it ends in an ellipsis. Use it instead of a `FittedBox` around
/// a `Text`, which can shrink text to any size.
///
/// The floor is [minFontSize], or by default [FitText.minFontSizeFor] the
/// style's size. Both follow the system text size, so a smaller system
/// setting still makes the text smaller.
class FitText extends StatelessWidget {
  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final double? minFontSize;
  final String? semanticsLabel;

  const FitText(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.minFontSize,
    this.semanticsLabel,
  }) : span = null;

  const FitText.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.minFontSize,
    this.semanticsLabel,
  }) : data = null;

  /// Default floor for text of [fontSize]: [AppTextStyles.minShrink] of it,
  /// never below [AppTextStyles.minFontSize] (small text doesn't shrink).
  static double minFontSizeFor(double fontSize) => math.min(
    fontSize,
    math.max(AppTextStyles.minFontSize, fontSize * AppTextStyles.minShrink),
  );

  /// The smallest factor [style] text of [fontSize] may be scaled by, given
  /// the system [scaler] and an optional explicit [minFontSize].
  static double minFactor(
    TextScaler scaler,
    double fontSize, {
    double? minFontSize,
  }) {
    final size = scaler.scale(fontSize);
    if (size <= 0) return 1;
    final floor = scaler.scale(minFontSize ?? minFontSizeFor(fontSize));
    return (floor / size).clamp(0.0, 1.0);
  }

  /// Whether [span] fits [width] in [maxLines] at the current text size,
  /// without shrinking.
  static bool fits(
    BuildContext context,
    InlineSpan span,
    double width, {
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      // Same inherited style the drawn text gets.
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [span],
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines && painter.width <= width;
    painter.dispose();
    return fits;
  }

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    final content = TextSpan(
      style: defaults.style.merge(style),
      text: data,
      children: span == null ? null : [span!],
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final align = textAlign ?? defaults.textAlign ?? TextAlign.start;
    final locale = Localizations.maybeLocaleOf(context);

    final floor = _floor(content, scaler);

    /// Lays the text out at [factor] within [width] and reads [read] from
    /// it; the painter is disposed right after.
    T measure<T>(double factor, double width, T Function(TextPainter) read) {
      final painter = TextPainter(
        text: content,
        textDirection: direction,
        textAlign: align,
        maxLines: maxLines,
        locale: locale,
        textScaler: ShrunkTextScaler(scaler, factor),
      )..layout(maxWidth: width);
      try {
        return read(painter);
      } finally {
        painter.dispose();
      }
    }

    bool fitsAt(double factor, double width) =>
        measure(factor, width, (p) => !p.didExceedMaxLines && p.width <= width);

    /// The largest factor (floor..1) at which the text fits [width].
    double factorFor(double width) {
      if (!width.isFinite || fitsAt(1, width)) return 1;
      if (!fitsAt(floor, width)) return floor;
      var lo = floor, hi = 1.0;
      for (var i = 0; i < 8; i++) {
        final mid = (lo + hi) / 2;
        if (fitsAt(mid, width)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return lo;
    }

    double naturalWidth(double factor) =>
        measure(factor, double.infinity, (p) => p.width);

    // Measured, so parents that ask for a natural size first
    // (IntrinsicWidth / IntrinsicHeight) work too.
    return MeasuredLayoutBuilder(
      measures: LayoutMeasures(
        maxWidth: () => naturalWidth(1),
        minWidth: () => naturalWidth(floor),
        heightFor: (width) => measure(factorFor(width), width, (p) => p.height),
      ),
      builder: (context, constraints) {
        final factor = constraints.hasBoundedWidth
            ? factorFor(constraints.maxWidth)
            : 1.0;
        return Text.rich(
          content,
          textScaler: factor == 1 ? scaler : ShrunkTextScaler(scaler, factor),
          textAlign: align,
          maxLines: maxLines,
          softWrap: maxLines > 1,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: semanticsLabel,
        );
      },
    );
  }

  /// The most any part of [content] may shrink: the floor of its most
  /// restrictive span, so no span ends up below its own minimum.
  double _floor(TextSpan content, TextScaler scaler) {
    var floor = 0.0;
    void visit(InlineSpan span, double inherited) {
      final size = span.style?.fontSize ?? inherited;
      if (span is! TextSpan) return;
      if (span.text?.isNotEmpty ?? false) {
        floor = math.max(
          floor,
          minFactor(scaler, size, minFontSize: minFontSize),
        );
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, size);
      }
    }

    visit(content, content.style?.fontSize ?? AppTextStyles.minFontSize);
    return floor == 0 ? 1 : floor;
  }
}

/// [base] scaled down further by [factor].
class ShrunkTextScaler extends TextScaler {
  final TextScaler base;
  final double factor;

  const ShrunkTextScaler(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is ShrunkTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
