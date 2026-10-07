import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

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
    final height = compact ? AppDimens.space32 : AppDimens.segmentHeight;
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
          for (final segment in segments)
            compact ? segment : Expanded(child: segment),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
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
          height: height,
          constraints: BoxConstraints(
            minWidth: compact ? AppDimens.space40 : 0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppDimens.space10 : AppDimens.space8,
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
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? context.text.bodySmall : context.text.labelMedium)
                ?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected ? v.buttonText : v.grayText,
                ),
          ),
        ),
      ),
    );
  }
}
