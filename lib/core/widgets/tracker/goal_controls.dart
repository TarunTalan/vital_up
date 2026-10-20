import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/services/ui_sounds.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Goal editors for the tracker goal sheet: one quiet visual language for
/// every metric. A grey track with the metric's accent as the only colour,
/// a sheet-coloured knob with an accent ring that lifts while dragged, the
/// recommended range as a light band and a grey note under the control.
/// Values glide when set from a chip or button and follow the finger while
/// dragged; every step clicks like [ValueRuler] (firmer on labelled marks).

/// A labelled point on a goal control's scale.
class GoalMark {
  final double value;
  final String label;

  const GoalMark(this.value, this.label);
}

/// Daily water goal: litres on a scale that gives everyday amounts (1-4 L)
/// most of the width, and how many 250 ml glasses that is.
class WaterGoalGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  const WaterGoalGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  static String _litres(double ml) {
    final l = ml / 1000;
    return l == l.roundToDouble() ? '${l.round()}' : l.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final glasses = (value / 250).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoalSlider(
          value: value,
          min: min,
          max: max,
          step: step,
          color: AppColors.trackWater,
          exponent: 0.5,
          marks: goalMarks(
            const [1000, 2000, 3000, 5000],
            min: min,
            max: max,
            label: (v) => '${_litres(v)} L',
          ),
          semanticValue: (v) => '${_litres(v)} litres',
          onChanged: onChanged,
        ),
        const SizedBox(height: AppDimens.space8),
        GoalNote(
          icon: Icons.local_drink_outlined,
          color: AppColors.trackWater,
          text: glasses == 1
              ? 'About 1 glass of 250 ml'
              : 'About $glasses glasses of 250 ml',
        ),
      ],
    );
  }
}

/// Daily screen time limit: a scale that gives the first hours most of the
/// width, the common 2 hour target as a band, and a calm note on the limit.
class ScreenTimeGoalGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  const ScreenTimeGoalGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  /// The common daily target for leisure screen time.
  static const double target = 120;

  static (IconData, Color, String) _note(double minutes) {
    if (minutes <= target) {
      return (
        Icons.check_circle_outline_rounded,
        AppColors.success,
        'Within the common 2 hour target',
      );
    }
    if (minutes <= 240) {
      return (
        Icons.schedule_rounded,
        AppColors.trackScreenTime,
        'Above 2 hours. Short breaks help',
      );
    }
    return (
      Icons.info_outline_rounded,
      AppColors.warning,
      'A high limit. Try lowering it over time',
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = _note(value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoalSlider(
          value: value,
          min: min,
          max: max,
          step: step,
          color: AppColors.trackScreenTime,
          exponent: 0.5,
          band: (from: min, to: target),
          marks: goalMarks(
            const [60, 120, 240, 480],
            min: min,
            max: max,
            label: shortMinutes,
          ),
          semanticValue: _spokenMinutes,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppDimens.space8),
        GoalNote(icon: icon, color: color, text: text),
      ],
    );
  }
}

/// Nightly sleep goal: a dial with the 7-9 hours adults need as a band,
/// sleep cycles in the middle and a note on the range under it.
class SleepGoalDial extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  const SleepGoalDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  static const double _rangeFrom = 420;
  static const double _rangeTo = 540;

  /// The dial opens at the bottom: 270 degrees from bottom left round to
  /// bottom right.
  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  State<SleepGoalDial> createState() => _SleepGoalDialState();
}

class _SleepGoalDialState extends State<SleepGoalDial>
    with _GoalFeedback<SleepGoalDial> {
  bool _dragging = false;

  _GoalScale get _scale =>
      _GoalScale(widget.min, widget.max, widget.step, exponent: 1);

  /// Ring geometry for a dial [width] wide.
  ({Offset center, double radius}) _geometry(double width) {
    const pad = AppDimens.goalKnob / 2 + AppDimens.goalKnobHalo;
    final size = math.min(width, AppDimens.goalDialMaxSize);
    final radius = size / 2 - pad;
    return (center: Offset(width / 2, pad + radius), radius: radius);
  }

  void _seek(Offset local, double width) {
    final g = _geometry(width);
    final d = local - g.center;
    var rel = (math.atan2(d.dy, d.dx) - SleepGoalDial._start) % (2 * math.pi);
    if (rel > SleepGoalDial._sweep) {
      // In the opening at the bottom: the nearer end.
      rel =
          rel > SleepGoalDial._sweep + (2 * math.pi - SleepGoalDial._sweep) / 2
          ? 0
          : SleepGoalDial._sweep;
    }
    _select(_scale.valueAt(rel / SleepGoalDial._sweep));
  }

  void _select(double v) {
    if (v == widget.value) return;
    feedback(strong: v % 60 == 0);
    widget.onChanged(v);
  }

  void _setDragging(bool on) {
    if (_dragging != on) setState(() => _dragging = on);
  }

  (IconData, Color, String) get _note {
    final v = widget.value;
    if (v < SleepGoalDial._rangeFrom) {
      return (
        Icons.info_outline_rounded,
        AppColors.warning,
        'Less than the 7 to 9 hours most adults need',
      );
    }
    if (v > SleepGoalDial._rangeTo) {
      return (
        Icons.info_outline_rounded,
        AppColors.trackSleep,
        'More than the usual 7 to 9 hours',
      );
    }
    return (
      Icons.check_circle_outline_rounded,
      AppColors.success,
      'In the 7 to 9 hours most adults need',
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final scale = _scale;
    final labelStyle = context.text.bodySmall!.copyWith(color: v.grayText);
    final textScaler = MediaQuery.textScalerOf(context);
    final labelHeight = _lineHeight(labelStyle, textScaler);
    final cycles = (widget.value / 90).round();
    final (icon, noteColor, note) = _note;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final g = _geometry(width);
            final endY = g.center.dy + g.radius * math.sin(math.pi / 4);
            final labelTop = endY + AppDimens.goalKnob / 2 + AppDimens.space4;
            final height = labelTop + labelHeight;
            bool onRing(Offset p) =>
                ((p - g.center).distance - g.radius).abs() <=
                AppDimens.goalKnob;

            return _GoalSemantics(
              value: widget.value,
              scale: scale,
              semanticValue: _spokenMinutes,
              onChanged: _select,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _GrabPanRecognizer:
                      GestureRecognizerFactoryWithHandlers<_GrabPanRecognizer>(
                        () => _GrabPanRecognizer(grabs: onRing),
                        (r) => r
                          ..grabs = onRing
                          ..dragStartBehavior = DragStartBehavior.down
                          ..onStart = ((d) {
                            _setDragging(true);
                            _seek(d.localPosition, width);
                          })
                          ..onUpdate = ((d) => _seek(d.localPosition, width))
                          ..onEnd = ((_) => _setDragging(false))
                          ..onCancel = (() => _setDragging(false)),
                      ),
                },
                child: SizedBox(
                  height: height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _Glide(
                          fraction: scale.fractionOf(widget.value),
                          dragging: _dragging,
                          builder: (fraction, lift) => CustomPaint(
                            painter: _DialPainter(
                              fraction: fraction,
                              lift: lift,
                              center: g.center,
                              radius: g.radius,
                              color: AppColors.trackSleep,
                              track: v.track!,
                              knobFill: v.surfaceElevated!,
                              band: scale.bandOf(
                                SleepGoalDial._rangeFrom,
                                SleepGoalDial._rangeTo,
                              ),
                              dots: [
                                for (
                                  var m = (widget.min / 60).ceil() * 60.0;
                                  m <= widget.max;
                                  m += 60
                                )
                                  scale.fractionOf(m),
                              ],
                              labels: [
                                shortMinutes(widget.min),
                                shortMinutes(widget.max),
                              ],
                              labelTop: labelTop,
                              labelStyle: labelStyle,
                              textScaler: textScaler,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: Rect.fromCenter(
                          center: g.center,
                          width: g.radius * 1.3,
                          height: g.radius * 1.2,
                        ),
                        child: IgnorePointer(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bedtime_outlined,
                                size: AppDimens.iconMd,
                                color: context.iconTint(AppColors.trackSleep),
                              ),
                              const SizedBox(height: AppDimens.space4),
                              Text(
                                cycles == 1
                                    ? 'About 1 sleep cycle'
                                    : 'About $cycles sleep cycles',
                                textAlign: TextAlign.center,
                                style: labelStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppDimens.space8),
        GoalNote(icon: icon, color: noteColor, text: note),
      ],
    );
  }
}

/// A horizontal goal slider: grey track, accent fill up to a lifted knob,
/// an optional recommended [band], dots and labels at [marks]. [exponent]
/// below 1 gives the low end more room (0.5: a square-root scale).
class GoalSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final Color color;
  final List<GoalMark> marks;
  final ({double from, double to})? band;
  final double exponent;

  /// Spoken value, e.g. "2.5 litres".
  final String Function(double value) semanticValue;
  final ValueChanged<double> onChanged;

  const GoalSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.color,
    required this.semanticValue,
    required this.onChanged,
    this.marks = const [],
    this.band,
    this.exponent = 1,
  });

  @override
  State<GoalSlider> createState() => _GoalSliderState();
}

class _GoalSliderState extends State<GoalSlider>
    with _GoalFeedback<GoalSlider> {
  bool _dragging = false;

  _GoalScale get _scale => _GoalScale(
    widget.min,
    widget.max,
    widget.step,
    exponent: widget.exponent,
  );

  void _seek(double dx, double width) {
    const inset = AppDimens.goalKnob / 2;
    final travel = width - 2 * inset;
    if (travel <= 0) return;
    _select(_scale.valueAt((dx - inset) / travel));
  }

  void _select(double v) {
    if (v == widget.value) return;
    feedback(
      strong: widget.marks.any((m) => (m.value - v).abs() < widget.step / 2),
    );
    widget.onChanged(v);
  }

  void _setDragging(bool on) {
    if (_dragging != on) setState(() => _dragging = on);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final scale = _scale;
    final labelStyle = context.text.bodySmall!.copyWith(color: v.grayText);
    final textScaler = MediaQuery.textScalerOf(context);
    // Labels just under the knob; the whole box stays tappable.
    const labelTop =
        kMinInteractiveDimension / 2 +
        AppDimens.goalKnob / 2 +
        AppDimens.space4;
    final height = labelTop + _lineHeight(labelStyle, textScaler);
    final band = widget.band;

    return _GoalSemantics(
      value: widget.value,
      scale: scale,
      semanticValue: widget.semanticValue,
      onChanged: _select,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seek(d.localPosition.dx, width),
            onHorizontalDragStart: (d) {
              _setDragging(true);
              _seek(d.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _setDragging(false),
            onHorizontalDragCancel: () => _setDragging(false),
            child: _Glide(
              fraction: scale.fractionOf(widget.value),
              dragging: _dragging,
              builder: (fraction, lift) => CustomPaint(
                size: Size(width, height),
                painter: _SliderPainter(
                  fraction: fraction,
                  lift: lift,
                  color: widget.color,
                  track: v.track!,
                  knobFill: v.surfaceElevated!,
                  band: band == null ? null : scale.bandOf(band.from, band.to),
                  marks: [
                    for (final m in widget.marks)
                      (fraction: scale.fractionOf(m.value), label: m.label),
                  ],
                  labelTop: labelTop,
                  labelStyle: labelStyle,
                  textScaler: textScaler,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A grey note under a goal control: a tinted icon and one short sentence.
class GoalNote extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const GoalNote({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppDimens.iconXs, color: context.iconTint(color)),
        const SizedBox(width: AppDimens.space8),
        Flexible(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ),
      ],
    );
  }
}

/// Marks for a goal scale: [min] and [max] plus each of [inside] strictly
/// between them.
List<GoalMark> goalMarks(
  List<double> inside, {
  required double min,
  required double max,
  required String Function(double value) label,
}) => [
  GoalMark(min, label(min)),
  for (final v in inside)
    if (v > min && v < max) GoalMark(v, label(v)),
  GoalMark(max, label(max)),
];

/// "45m", "2h", "1h 30m".
String shortMinutes(double minutes) {
  final m = minutes.round();
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '${h}h' : '${h}h ${rest}m';
}

String _spokenMinutes(double minutes) {
  final m = minutes.round();
  final h = m ~/ 60;
  final rest = m % 60;
  final hours = h == 1 ? '1 hour' : '$h hours';
  final mins = rest == 1 ? '1 minute' : '$rest minutes';
  if (h == 0) return mins;
  return rest == 0 ? hours : '$hours $mins';
}

double _lineHeight(TextStyle style, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: '0', style: style),
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Maps goal values to 0-1 along a control and back, snapped to [step].
class _GoalScale {
  final double min;
  final double max;
  final double step;
  final double exponent;

  const _GoalScale(this.min, this.max, this.step, {required this.exponent});

  double fractionOf(double value) {
    if (max <= min) return 0;
    final linear = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return math.pow(linear, exponent).toDouble();
  }

  double valueAt(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    final raw = min + math.pow(f, 1 / exponent) * (max - min);
    final snapped = ((raw - min) / step).round() * step + min;
    return snapped.clamp(min, max).toDouble();
  }

  ({double from, double to})? bandOf(double from, double to) {
    final a = fractionOf(math.max(from, min));
    final b = fractionOf(math.min(to, max));
    return b > a ? (from: a, to: b) : null;
  }
}

/// Sound and vibration per step, firmer on labelled marks, at most one per
/// 35 ms of frame time (as [ValueRuler]).
mixin _GoalFeedback<T extends StatefulWidget> on State<T> {
  static const _gap = Duration(milliseconds: 35);
  Duration? _lastFeedback;

  @override
  void initState() {
    super.initState();
    UiSounds.prepare();
  }

  void feedback({required bool strong}) {
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final last = _lastFeedback;
    if (last != null && now - last < _gap) return;
    _lastFeedback = now;
    if (strong) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    UiSounds.tick(strong: strong);
  }
}

/// A slider for screen readers: one [_GoalScale.step] per swipe.
class _GoalSemantics extends StatelessWidget {
  final double value;
  final _GoalScale scale;
  final String Function(double value) semanticValue;
  final ValueChanged<double> onChanged;
  final Widget child;

  const _GoalSemantics({
    required this.value,
    required this.scale,
    required this.semanticValue,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final up = math.min(value + scale.step, scale.max);
    final down = math.max(value - scale.step, scale.min);
    return Semantics(
      slider: true,
      value: semanticValue(value),
      increasedValue: semanticValue(up),
      decreasedValue: semanticValue(down),
      onIncrease: value < scale.max ? () => onChanged(up) : null,
      onDecrease: value > scale.min ? () => onChanged(down) : null,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// Glides to [fraction] when the value is set from outside (chips, +/-,
/// a tap) and follows it at once while [dragging]; [builder] also gets the
/// knob's lift (0 resting, 1 dragged).
class _Glide extends StatelessWidget {
  final double fraction;
  final bool dragging;
  final Widget Function(double fraction, double lift) builder;

  const _Glide({
    required this.fraction,
    required this.dragging,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: dragging ? Duration.zero : AppDurations.medium,
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: dragging ? 1 : 0),
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        builder: (context, lift, _) => builder(f, lift),
      ),
    );
  }
}

/// A pan that wins the gesture arena the moment the finger lands on the
/// ring, before the sheet's drag-to-close or the page's scroll claim it.
class _GrabPanRecognizer extends PanGestureRecognizer {
  bool Function(Offset localPosition) grabs;

  _GrabPanRecognizer({required this.grabs});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (grabs(event.localPosition)) resolve(GestureDisposition.accepted);
  }
}

/// The knob: a sheet-coloured circle with a thin accent ring and a soft
/// shadow; while dragged ([lift] 1) it grows a little inside a light halo.
void _paintKnob(
  Canvas canvas,
  Offset at, {
  required Color color,
  required Color fill,
  required double lift,
}) {
  final r = AppDimens.goalKnob / 2 + AppDimens.space2 * lift;
  if (lift > 0) {
    canvas.drawCircle(
      at,
      r + AppDimens.goalKnobHalo * lift,
      Paint()..color = color.withValues(alpha: 0.16 * lift),
    );
  }
  canvas.drawCircle(
    at + const Offset(0, 1),
    r,
    Paint()
      ..color = AppColors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(at, r, Paint()..color = fill);
  canvas.drawCircle(
    at,
    r - AppDimens.borderThick / 2,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppDimens.borderThick,
  );
}

TextPainter _label(String text, TextStyle style, TextScaler textScaler) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

class _SliderPainter extends CustomPainter {
  final double fraction;
  final double lift;
  final Color color;
  final Color track;
  final Color knobFill;
  final ({double from, double to})? band;
  final List<({double fraction, String label})> marks;
  final double labelTop;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  _SliderPainter({
    required this.fraction,
    required this.lift,
    required this.color,
    required this.track,
    required this.knobFill,
    required this.band,
    required this.marks,
    required this.labelTop,
    required this.labelStyle,
    required this.textScaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AppDimens.goalKnob / 2;
    const h = AppDimens.progressHeight;
    final travel = size.width - 2 * inset;
    final y = kMinInteractiveDimension / 2;
    double xAt(double f) => inset + f * travel;
    RRect bar(double from, double to) => RRect.fromLTRBR(
      from,
      y - h / 2,
      to,
      y + h / 2,
      const Radius.circular(h / 2),
    );

    canvas.drawRRect(bar(0, size.width), Paint()..color = track);
    final band = this.band;
    if (band != null) {
      canvas.drawRRect(
        bar(xAt(band.from) - h / 2, xAt(band.to) + h / 2),
        Paint()..color = color.withValues(alpha: 0.22),
      );
    }
    final knobX = xAt(fraction);
    canvas.drawRRect(bar(0, knobX), Paint()..color = color);

    // Dots on the track at inner marks: sheet colour on the fill, grey
    // beyond it.
    for (final m in marks) {
      if (m.fraction <= 0.001 || m.fraction >= 0.999) continue;
      final x = xAt(m.fraction);
      canvas.drawCircle(
        Offset(x, y),
        AppDimens.space2,
        Paint()
          ..color = x <= knobX
              ? knobFill.withValues(alpha: 0.7)
              : labelStyle.color!.withValues(alpha: 0.5),
      );
    }

    _paintLabels(canvas, size.width, xAt);
    _paintKnob(
      canvas,
      Offset(knobX, y),
      color: color,
      fill: knobFill,
      lift: lift,
    );
  }

  /// Labels centred under their marks, kept inside the width; one that
  /// would crowd the previous is left out (the last one always shows).
  void _paintLabels(Canvas canvas, double width, double Function(double) xAt) {
    const gap = AppDimens.space12;
    final placed = <({TextPainter painter, double left})>[];
    final all = <TextPainter>[];
    for (var i = 0; i < marks.length; i++) {
      final p = _label(marks[i].label, labelStyle, textScaler);
      all.add(p);
      final left = (xAt(marks[i].fraction) - p.width / 2)
          .clamp(0.0, math.max(0.0, width - p.width))
          .toDouble();
      bool crowds() =>
          placed.isNotEmpty &&
          left < placed.last.left + placed.last.painter.width + gap;
      if (i == marks.length - 1) {
        while (placed.length > 1 && crowds()) {
          placed.removeLast();
        }
        if (crowds()) continue;
      } else if (crowds()) {
        continue;
      }
      placed.add((painter: p, left: left));
    }
    for (final l in placed) {
      l.painter.paint(canvas, Offset(l.left, labelTop));
    }
    for (final p in all) {
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.fraction != fraction ||
      old.lift != lift ||
      old.color != color ||
      old.track != track ||
      old.knobFill != knobFill ||
      old.band != band ||
      old.labelTop != labelTop ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      !_sameMarks(old.marks, marks);

  static bool _sameMarks(
    List<({double fraction, String label})> a,
    List<({double fraction, String label})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _DialPainter extends CustomPainter {
  final double fraction;
  final double lift;
  final Offset center;
  final double radius;
  final Color color;
  final Color track;
  final Color knobFill;
  final ({double from, double to})? band;
  final List<double> dots;
  final List<String> labels;
  final double labelTop;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  _DialPainter({
    required this.fraction,
    required this.lift,
    required this.center,
    required this.radius,
    required this.color,
    required this.track,
    required this.knobFill,
    required this.band,
    required this.dots,
    required this.labels,
    required this.labelTop,
    required this.labelStyle,
    required this.textScaler,
  });

  static const _start = SleepGoalDial._start;
  static const _sweep = SleepGoalDial._sweep;

  Offset _at(double f) {
    final a = _start + f * _sweep;
    return center + Offset(math.cos(a), math.sin(a)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint stroke(Color c, {StrokeCap cap = StrokeCap.round}) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppDimens.goalDialStroke
      ..strokeCap = cap;

    canvas.drawArc(rect, _start, _sweep, false, stroke(track));
    final band = this.band;
    if (band != null) {
      canvas.drawArc(
        rect,
        _start + band.from * _sweep,
        (band.to - band.from) * _sweep,
        false,
        stroke(color.withValues(alpha: 0.22)),
      );
    }
    if (fraction > 0) {
      canvas.drawArc(rect, _start, fraction * _sweep, false, stroke(color));
    }

    for (final f in dots) {
      if (f <= 0.001 || f >= 0.999) continue;
      canvas.drawCircle(
        _at(f),
        AppDimens.space2,
        Paint()
          ..color = f <= fraction
              ? knobFill.withValues(alpha: 0.7)
              : labelStyle.color!.withValues(alpha: 0.5),
      );
    }

    // End labels centred under the ring's two ends.
    for (var i = 0; i < labels.length && i < 2; i++) {
      final p = _label(labels[i], labelStyle, textScaler);
      final x = _at(i == 0 ? 0 : 1).dx;
      p.paint(canvas, Offset(x - p.width / 2, labelTop));
      p.dispose();
    }

    _paintKnob(canvas, _at(fraction), color: color, fill: knobFill, lift: lift);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.lift != lift ||
      old.center != center ||
      old.radius != radius ||
      old.color != color ||
      old.track != track ||
      old.knobFill != knobFill ||
      old.band != band ||
      old.labelTop != labelTop ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.labels.join() != labels.join() ||
      old.dots.length != dots.length;
}
