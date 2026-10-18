import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

/// Figma segmented tabs (Move / Rest / Fuel / Vitals): glass track, the
/// selected segment filled with primary and lifted by the segment shadow.
///
/// [compact] is the small inline version for list rows (unit pickers).
class AppSegmentedControl<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  final bool compact;

  const AppSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    // Grows with the text size so labels never clip.
    final height = context.textScaled(
      compact ? AppDimens.space32 : AppDimens.segmentHeight,
    );
    // Each segment's share follows its label, so a long one
    // ("Occasionally") gets the room it needs instead of wrapping.
    final style = _Segment.styleOf(context, compact: compact);
    final scaler = MediaQuery.textScalerOf(context);
    int flexOf(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      // A shared base keeps similar labels equal; only a long one stands
      // out.
      return (width + _Segment.padding * 2 + AppDimens.space48).ceil().clamp(
        1,
        1 << 20,
      );
    }

    final segments = [
      for (final value in values)
        _Segment(
          label: label(value),
          selected: value == selected,
          height: height,
          compact: compact,
          onTap: () {
            if (value != selected) onChanged(value);
          },
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimens.space4),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(
          compact ? AppDimens.radiusToast : AppDimens.radiusCard,
        ),
        border: Border.all(color: v.glassBorder!),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < segments.length; i++)
            compact
                ? segments[i]
                : Expanded(flex: flexOf(label(values[i])), child: segments[i]),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  /// Horizontal padding of a full-size segment.
  static const double padding = AppDimens.space8;

  static TextStyle? styleOf(BuildContext context, {required bool compact}) =>
      (compact ? context.text.bodySmall : context.text.labelMedium)?.copyWith(
        fontWeight: FontWeight.w500,
      );

  static final _hiddenShadow = [
    for (final s in AppShadows.segment)
      s.copyWith(color: s.color.withValues(alpha: 0)),
  ];

  final String label;
  final bool selected;
  final double height;
  final bool compact;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.height,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final primary = context.colors.primary;
    final radius = BorderRadius.circular(
      compact ? AppDimens.radiusXs * 2 : AppDimens.radiusSm,
    );
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          // A minimum, not a fixed height: large system text grows it.
          constraints: BoxConstraints(
            minWidth: compact ? AppDimens.space40 : 0,
            minHeight: height,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppDimens.space10 : padding,
            vertical: AppDimens.space4,
          ),
          alignment: Alignment.center,
          // Fade between primary and a transparent primary, and between the
          // shadow and a transparent copy of it: animating from
          // Colors.transparent or from no shadow passes through black.
          decoration: BoxDecoration(
            color: selected ? primary : primary.withValues(alpha: 0),
            borderRadius: radius,
            boxShadow: selected ? AppShadows.segment : _hiddenShadow,
          ),
          // One line; shrinks a little before it would wrap.
          child: FitText(
            label,
            textAlign: TextAlign.center,
            style: styleOf(
              context,
              compact: compact,
            )?.copyWith(color: selected ? v.buttonText : v.grayText),
          ),
        ),
      ),
    );
  }
}
