import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// A sliding scale for picking a number: drag or fling the ruler under a
/// fixed centre marker. It glides to a stop and snaps to [step], with a
/// light haptic tick per step; tapping a mark glides to it. Screen readers
/// get a slider that moves one [step] per swipe.
///
/// Ticks every [step], taller every [midEvery] steps and labelled every
/// [majorEvery] steps (e.g. 0.1 / 0.5 / 1 kg). The ends fade out.
class ValueRuler extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final int majorEvery;
  final int midEvery;
  final ValueChanged<double> onChanged;

  /// Marker colour (the metric's accent).
  final Color color;

  /// Spoken value, e.g. "72.4 kilograms".
  final String Function(double value) semanticValue;

  const ValueRuler({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.color,
    required this.semanticValue,
    this.step = 0.1,
    this.majorEvery = 10,
    this.midEvery = 5,
  });

  @override
  State<ValueRuler> createState() => _ValueRulerState();
}

class _ValueRulerState extends State<ValueRuler>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.value,
  )..addListener(_report);

  /// Last value reported to [ValueRuler.onChanged] (already snapped).
  late double _reported = _snap(widget.value);

  static const double _spacing = AppDimens.rulerTickSpacing;

  @override
  void didUpdateWidget(ValueRuler old) {
    super.didUpdateWidget(old);
    // Typed elsewhere: jump there unless the user is mid-gesture.
    if (!_position.isAnimating && _snap(widget.value) != _reported) {
      _reported = _snap(widget.value);
      _position.value = widget.value;
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(widget.min, widget.max).toDouble();

  /// [v] on the nearest tick, without float noise (72.39999 -> 72.4).
  double _snap(double v) {
    final steps = ((_clamp(v) - widget.min) / widget.step).round();
    final decimals = math.max(0, -(math.log(widget.step) / math.ln10).floor());
    return double.parse(
      (widget.min + steps * widget.step).toStringAsFixed(decimals),
    );
  }

  void _report() {
    final snapped = _snap(_position.value);
    if (snapped == _reported) return;
    _reported = snapped;
    HapticFeedback.selectionClick();
    widget.onChanged(snapped);
  }

  /// Units per logical pixel of drag.
  double get _unitsPerPx => widget.step / _spacing;

  void _dragUpdate(DragUpdateDetails d) {
    _position.value = _clamp(_position.value - d.delta.dx * _unitsPerPx);
  }

  void _dragEnd(DragEndDetails d) {
    final velocity = -d.velocity.pixelsPerSecond.dx * _unitsPerPx;
    // Glide like a flung list: friction brings it to a stop, then the
    // nearest tick is where it lands.
    const drag = 0.135;
    final glide = velocity / -math.log(drag);
    _glideTo(_position.value + glide, speed: velocity.abs());
  }

  void _glideTo(double target, {double speed = 0}) {
    final to = _snap(target);
    final distance = (to - _position.value).abs();
    if (distance == 0) return;
    final ms = speed > 0
        ? (distance / speed * 1000 * 2).clamp(180, 900)
        : (distance / widget.step * 12).clamp(180, 500);
    _position.animateTo(
      to,
      duration: Duration(milliseconds: ms.round()),
      curve: Curves.decelerate,
    );
  }

  void _tapUp(TapUpDetails d, double width) {
    final dx = d.localPosition.dx - width / 2;
    _glideTo(_position.value + dx * _unitsPerPx);
  }

  void _nudge(int steps) {
    _position.stop();
    _glideTo(_reported + steps * widget.step);
  }

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText!;
    final labelStyle = context.text.labelSmall!.copyWith(color: grey);
    final scaler = MediaQuery.textScalerOf(context);
    final labelHeight = scaler.scale(labelStyle.fontSize!) * 1.4;
    final height =
        AppDimens.rulerIndicatorHeight + AppDimens.space8 + labelHeight;
    final marker = context.iconTint(widget.color);
    return Semantics(
      slider: true,
      value: widget.semanticValue(_reported),
      increasedValue: widget.semanticValue(_snap(_reported + widget.step)),
      decreasedValue: widget.semanticValue(_snap(_reported - widget.step)),
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _position.stop(),
            onHorizontalDragUpdate: _dragUpdate,
            onHorizontalDragEnd: _dragEnd,
            onTapUp: (d) => _tapUp(d, constraints.maxWidth),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The ends fade out so the scale reads as endless.
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    colors: [
                      grey.withValues(alpha: 0),
                      grey,
                      grey,
                      grey.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.22, 0.78, 1],
                  ).createShader(rect),
                  child: AnimatedBuilder(
                    animation: _position,
                    builder: (context, _) => CustomPaint(
                      size: Size(constraints.maxWidth, height),
                      painter: _RulerPainter(
                        value: _position.value,
                        min: widget.min,
                        max: widget.max,
                        step: widget.step,
                        majorEvery: widget.majorEvery,
                        midEvery: widget.midEvery,
                        tickColor: grey,
                        labelStyle: labelStyle,
                        textScaler: scaler,
                      ),
                    ),
                  ),
                ),
                // Fixed centre marker.
                Container(
                  width: AppDimens.rulerIndicatorWidth,
                  height: AppDimens.rulerIndicatorHeight,
                  decoration: BoxDecoration(
                    color: marker,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    boxShadow: [
                      BoxShadow(
                        color: marker.withValues(alpha: 0.35),
                        blurRadius: AppDimens.space8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final double step;
  final int majorEvery;
  final int midEvery;
  final Color tickColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  _RulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.majorEvery,
    required this.midEvery,
    required this.tickColor,
    required this.labelStyle,
    required this.textScaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = AppDimens.rulerTickSpacing;
    final centre = size.width / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = AppDimens.borderThick;
    // Only the ticks on screen (the range can hold thousands).
    final half = (centre / spacing).ceil() + 1;
    final current = ((value - min) / step).round();
    final last = ((max - min) / step).round();
    for (var i = current - half; i <= current + half; i++) {
      if (i < 0 || i > last) continue;
      final x = centre + ((min + i * step) - value) / step * spacing;
      final major = i % majorEvery == 0;
      final mid = i % midEvery == 0;
      final length = major
          ? AppDimens.rulerTickMajor
          : mid
          ? AppDimens.rulerTickMid
          : AppDimens.rulerTickMinor;
      paint.color = tickColor.withValues(
        alpha: major ? 0.9 : (mid ? 0.6 : 0.35),
      );
      // Ticks hang from the top, centred under the marker's top.
      final top = (AppDimens.rulerIndicatorHeight - length) / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + length), paint);
      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: (min + i * step).round().toString(),
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        label.paint(
          canvas,
          Offset(
            x - label.width / 2,
            AppDimens.rulerIndicatorHeight + AppDimens.space8,
          ),
        );
        label.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.value != value ||
      old.tickColor != tickColor ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.min != min ||
      old.max != max;
}
