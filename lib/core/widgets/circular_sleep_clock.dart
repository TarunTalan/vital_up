import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';

/// A 24-hour clock for a night's sleep: drag the moon (bedtime) or the sun
/// (wake time), or drag the arc between them to move the whole night and
/// keep its length. Snaps to 5 minutes with a light haptic tick. The middle
/// shows how long that is and how it compares with the sleep [goal].
/// Minutes from bedtime to wake time round the 24-hour dial (0-1439).
int sleepGapMinutes(TimeOfDay bed, TimeOfDay wake) =>
    (wake.hour * 60 + wake.minute - bed.hour * 60 - bed.minute) % (24 * 60);

/// [gap] kept within [min]..[max] minutes. Out of range it stays at the
/// limit nearer to where it was ([previous]), so a handle pushed against
/// the other one stops there instead of jumping round to the far side,
/// and equal bed and wake times can't happen.
int clampSleepGap(
  int gap, {
  required int previous,
  required int min,
  required int max,
}) {
  if (gap >= min && gap <= max) return gap;
  return previous <= (min + max) / 2 ? min : max;
}

class CircularSleepClockPicker extends StatefulWidget {
  final TimeOfDay initialBedTime;
  final TimeOfDay initialWakeTime;
  final ValueChanged<TimeOfDay>? onBedTimeChanged;
  final ValueChanged<TimeOfDay>? onWakeTimeChanged;
  final void Function(TimeOfDay bed, TimeOfDay wake)? onChanged;

  /// Nightly sleep goal: the middle says "Goal met" or how far short.
  final Duration? goal;

  /// The night's length to show in the middle, from whoever knows the
  /// dates: real elapsed time (a daylight-saving night from 23:00 to 07:00
  /// is 7 or 9 hours, not the dial's 8) or a phone estimate's time asleep.
  /// The dial alone only knows clock positions, so without it the middle
  /// shows the wall-clock gap.
  final Duration? duration;

  /// Shortest and longest night the handles allow (the save rules), so
  /// the dial never shows a night that can't be saved.
  final Duration minDuration;
  final Duration maxDuration;

  /// Told the clock's size after each layout, so a sheet can make room
  /// when the clock would get smaller than [minClockSize].
  final ValueChanged<double>? onClockSize;

  /// Smallest size that keeps the clock readable and easy to drag.
  static const double minClockSize = 200;

  const CircularSleepClockPicker({
    super.key,
    this.initialBedTime = const TimeOfDay(hour: 23, minute: 0),
    this.initialWakeTime = const TimeOfDay(hour: 7, minute: 0),
    this.onBedTimeChanged,
    this.onWakeTimeChanged,
    this.onChanged,
    this.goal,
    this.duration,
    this.onClockSize,
    this.minDuration = const Duration(minutes: 30),
    this.maxDuration = const Duration(hours: 18),
  });

  @override
  State<CircularSleepClockPicker> createState() =>
      _CircularSleepClockPickerState();
}

class _CircularSleepClockPickerState extends State<CircularSleepClockPicker> {
  late TimeOfDay _bedTime;
  late TimeOfDay _wakeTime;
  _ActiveHandle _activeHandle = _ActiveHandle.none;
  double? _reportedSize;

  /// While dragging the arc: where the drag began and the times then.
  double _arcStartAngle = 0;
  TimeOfDay _arcStartBed = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _arcStartWake = const TimeOfDay(hour: 0, minute: 0);

  @override
  void initState() {
    super.initState();
    _bedTime = widget.initialBedTime;
    _wakeTime = widget.initialWakeTime;
  }

  @override
  void didUpdateWidget(covariant CircularSleepClockPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBedTime != widget.initialBedTime) {
      _bedTime = widget.initialBedTime;
    }
    if (oldWidget.initialWakeTime != widget.initialWakeTime) {
      _wakeTime = widget.initialWakeTime;
    }
  }

  // Convert TimeOfDay to angle in radians (0 at 12:00 AM midnight at top, pi at 12:00 PM noon at bottom)
  double _timeToAngle(TimeOfDay time) {
    final totalMinutes = time.hour * 60 + time.minute;
    final fraction = totalMinutes / (24 * 60);
    return fraction * 2 * math.pi - (math.pi / 2);
  }

  // Convert angle in radians to TimeOfDay snapped to nearest 5 minutes
  TimeOfDay _angleToTime(double angle) {
    var normalized = angle + (math.pi / 2);
    while (normalized < 0) {
      normalized += 2 * math.pi;
    }
    while (normalized >= 2 * math.pi) {
      normalized -= 2 * math.pi;
    }

    final fraction = normalized / (2 * math.pi);
    var totalMinutes = (fraction * 24 * 60).round();

    // Snap to nearest 5 minutes
    totalMinutes = ((totalMinutes + 2) ~/ 5) * 5;
    if (totalMinutes >= 24 * 60) totalMinutes = 0;

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }

  /// [text] with non-breaking spaces, so it never wraps inside.
  static String _keep(String text) => text.replaceAll(' ', '\u00a0');

  /// "45m", "1h 10m", "8h".
  static String _short(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Duration _getSleepDuration() =>
      Duration(minutes: sleepGapMinutes(_bedTime, _wakeTime));

  /// [gap] within the allowed night length, judged from the current one.
  int _allowedGap(int gap) => clampSleepGap(
    gap,
    previous: sleepGapMinutes(_bedTime, _wakeTime),
    min: widget.minDuration.inMinutes,
    max: widget.maxDuration.inMinutes,
  );

  /// Moves bedtime to [time], kept within the allowed night length.
  void _setBed(TimeOfDay time) {
    final gap = _allowedGap(sleepGapMinutes(time, _wakeTime));
    final bed = _shift(_wakeTime, -gap);
    if (bed == _bedTime) return;
    setState(() => _bedTime = bed);
    widget.onBedTimeChanged?.call(bed);
    widget.onChanged?.call(_bedTime, _wakeTime);
    HapticFeedback.lightImpact();
  }

  /// Moves wake time to [time], kept within the allowed night length.
  void _setWake(TimeOfDay time) {
    final gap = _allowedGap(sleepGapMinutes(_bedTime, time));
    final wake = _shift(_bedTime, gap);
    if (wake == _wakeTime) return;
    setState(() => _wakeTime = wake);
    widget.onWakeTimeChanged?.call(wake);
    widget.onChanged?.call(_bedTime, _wakeTime);
    HapticFeedback.lightImpact();
  }

  /// What a touch at [point] would grab: a handle (the nearer one when
  /// both are close), the band between them, or nothing.
  _ActiveHandle _grabAt(Offset point, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _ringInset;
    Offset at(TimeOfDay t) {
      final angle = _timeToAngle(t);
      return center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }

    final toBed = (point - at(_bedTime)).distance;
    final toWake = (point - at(_wakeTime)).distance;
    const hitRadius = 38.0;
    if (toBed < hitRadius && toBed <= toWake) return _ActiveHandle.bed;
    if (toWake < hitRadius) return _ActiveHandle.wake;
    if (_onArc(point, center, radius)) return _ActiveHandle.arc;
    return _ActiveHandle.none;
  }

  void _onPanStart(Offset localPosition, Size size) {
    final grab = _grabAt(localPosition, size);
    if (grab == _ActiveHandle.arc) {
      // Grabbing the band itself moves the whole night.
      final center = Offset(size.width / 2, size.height / 2);
      _arcStartAngle = math.atan2(
        localPosition.dy - center.dy,
        localPosition.dx - center.dx,
      );
      _arcStartBed = _bedTime;
      _arcStartWake = _wakeTime;
    }
    setState(() => _activeHandle = grab);
    if (grab != _ActiveHandle.none) HapticFeedback.selectionClick();
  }

  void _onPanUpdate(Offset localPosition, Size size) {
    if (_activeHandle == _ActiveHandle.none) return;

    final center = Offset(size.width / 2, size.height / 2);
    final touchOffset = localPosition - center;
    final angle = math.atan2(touchOffset.dy, touchOffset.dx);
    final newTime = _angleToTime(angle);

    if (_activeHandle == _ActiveHandle.arc) {
      var delta = angle - _arcStartAngle;
      while (delta > math.pi) {
        delta -= 2 * math.pi;
      }
      while (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      final minutes = (delta / (2 * math.pi) * 24 * 60 / 5).round() * 5;
      final bed = _shift(_arcStartBed, minutes);
      final wake = _shift(_arcStartWake, minutes);
      if (bed != _bedTime) {
        setState(() {
          _bedTime = bed;
          _wakeTime = wake;
        });
        widget.onBedTimeChanged?.call(bed);
        widget.onWakeTimeChanged?.call(wake);
        widget.onChanged?.call(_bedTime, _wakeTime);
        HapticFeedback.lightImpact();
      }
    } else if (_activeHandle == _ActiveHandle.bed) {
      _setBed(newTime);
    } else if (_activeHandle == _ActiveHandle.wake) {
      _setWake(newTime);
    }
  }

  void _onPanEnd() {
    setState(() => _activeHandle = _ActiveHandle.none);
  }

  /// [time] moved by [minutes], wrapping round midnight.
  static TimeOfDay _shift(TimeOfDay time, int minutes) {
    final total = (time.hour * 60 + time.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  /// [point] is on the ring, inside the arc from bedtime to wake time.
  bool _onArc(Offset point, Offset center, double radius) {
    final distance = (point - center).distance;
    if ((distance - radius).abs() > _ringStroke) return false;
    final bed = _timeToAngle(_bedTime);
    var sweep = _timeToAngle(_wakeTime) - bed;
    if (sweep < 0) sweep += 2 * math.pi;
    var at = math.atan2(point.dy - center.dy, point.dx - center.dx) - bed;
    while (at < 0) {
      at += 2 * math.pi;
    }
    return at <= sweep;
  }

  static const double _ringStroke = 30;

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final duration = widget.duration ?? _getSleepDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final goal = widget.goal;
    final goalMet = goal != null && duration >= goal;
    final goalNote = goal == null
        ? null
        : goalMet
        ? 'Goal met'
        // Breaks only between the two halves, never leaving "goal" alone.
        : '${_keep('${_short(goal - duration)} under')} '
              '${_keep('your ${_short(goal)} goal')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Takes the height left after the time cards (in a sheet that
        // doesn't scroll), at most its normal size.
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final clockSize = [
                constraints.maxWidth,
                constraints.maxHeight,
                _maxClockSize,
              ].reduce(math.min);
              final size = Size(clockSize, clockSize);
              if (clockSize != _reportedSize) {
                _reportedSize = clockSize;
                final report = widget.onClockSize;
                if (report != null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => report(clockSize),
                  );
                }
              }
              bool grabs(Offset p) => _grabAt(p, size) != _ActiveHandle.none;
              return SizedBox(
                width: clockSize,
                height: clockSize,
                // A touch on a handle or the band belongs to the clock at
                // once, so moving it up or down never scrolls or drags the
                // sheet; touches elsewhere still do.
                child: RawGestureDetector(
                  gestures: {
                    _GrabPanRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _GrabPanRecognizer
                        >(
                          () => _GrabPanRecognizer(grabs: grabs),
                          (r) => r
                            ..grabs = grabs
                            ..dragStartBehavior = DragStartBehavior.down
                            ..onStart = ((d) =>
                                _onPanStart(d.localPosition, size))
                            ..onUpdate = ((d) =>
                                _onPanUpdate(d.localPosition, size))
                            ..onEnd = ((_) => _onPanEnd())
                            ..onCancel = _onPanEnd,
                        ),
                  },
                  child: CustomPaint(
                    size: Size(clockSize, clockSize),
                    painter: _SleepClockPainter(
                      bedAngle: _timeToAngle(_bedTime),
                      wakeAngle: _timeToAngle(_wakeTime),
                      trackColor: v.track!,
                      nightColor: AppColors.sleep,
                      morningColor: AppColors.primary,
                      knobFill: v.surfaceElevated!,
                      moonColor: AppColors.readableOn(
                        AppColors.sleep,
                        v.surfaceElevated!,
                      ),
                      sunColor: AppColors.readableOn(
                        AppColors.warning,
                        v.surfaceElevated!,
                      ),
                      dialTextColor: v.grayText!,
                      textScaler: MediaQuery.textScalerOf(context),
                      active: _activeHandle,
                    ),
                    // The middle shows only when it fits inside the dial (not
                    // on a tiny clock at huge text); Save shows the duration
                    // too.
                    child:
                        !_centreFits(
                          context,
                          clockSize,
                          minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m',
                          goalNote,
                        )
                        ? null
                        : Center(
                            // Inside the dial's ticks, so a wrapped goal line never
                            // runs under the ring or a handle.
                            child: SizedBox(
                              width: _innerWidth(clockSize),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text.rich(
                                    figureSpan(
                                      context,
                                      minutes == 0
                                          ? '${hours}h'
                                          : '${hours}h ${minutes}m',
                                    ),
                                  ),
                                  if (goalNote case final note?) ...[
                                    const SizedBox(height: AppDimens.space4),
                                    Text(
                                      note,
                                      textAlign: TextAlign.center,
                                      style: context.text.labelSmall?.copyWith(
                                        color: goalMet
                                            ? context.iconTint(v.success!)
                                            : v.grayText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.space16),
        // Bed and wake time cards: side by side, or stacked when a time
        // ("11:15 PM") wouldn't fit one line beside the other card.
        _TimeCards(
          bedTime: _bedTime,
          wakeTime: _wakeTime,
          bed: _ScheduleTimeCard(
            icon: Icons.bedtime_rounded,
            iconColor: AppColors.sleep,
            title: 'Bedtime',
            time: _bedTime,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _bedTime,
              );
              if (t != null && mounted) _setBed(t);
            },
          ),
          wake: _ScheduleTimeCard(
            icon: Icons.wb_sunny_rounded,
            iconColor: AppColors.warning,
            title: 'Wake up',
            time: _wakeTime,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _wakeTime,
              );
              if (t != null && mounted) _setWake(t);
            },
          ),
        ),
      ],
    );
  }

  /// Room for text in the dial's middle: inside the ring and its ticks,
  /// narrowed a little since the circle closes in above and below.
  static double _innerWidth(double clockSize) => math.max(
    0,
    (clockSize - 2 * (_ringInset + _ringStroke / 2 + _tickRoom)) * 0.85,
  );

  /// Ticks and their gap inside the ring.
  static const double _tickRoom = 14;

  /// The duration and goal line fit inside the dial of [clockSize].
  bool _centreFits(
    BuildContext context,
    double clockSize,
    String figure,
    String? note,
  ) {
    final width = _innerWidth(clockSize);
    final painter = TextPainter(
      text: figureSpan(context, figure),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    var height = painter.height;
    final figureFits = painter.width <= width;
    painter.dispose();
    if (!figureFits) return false;
    if (note != null) {
      final notePainter = TextPainter(
        text: TextSpan(
          text: note,
          style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: width);
      final noteFits =
          !notePainter.didExceedMaxLines && notePainter.width <= width;
      height += AppDimens.space4 + notePainter.height;
      notePainter.dispose();
      if (!noteFits) return false;
    }
    // The inner circle's height at the text's widest point.
    return height <= _innerWidth(clockSize);
  }

  /// Largest the clock gets (phones with room to spare).
  static const double _maxClockSize = 280;

  /// Gap between the clock's edge and the ring's centre line (room for the
  /// hour labels).
  static const double _ringInset = 24;
}

enum _ActiveHandle { none, bed, wake, arc }

/// A pan that wins the gesture arena the moment the finger lands on
/// something it [grabs] (a handle or the band), before the sheet's vertical
/// scroll or drag-to-close can claim it.
class _GrabPanRecognizer extends PanGestureRecognizer {
  bool Function(Offset localPosition) grabs;

  _GrabPanRecognizer({required this.grabs});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (grabs(event.localPosition)) resolve(GestureDisposition.accepted);
  }
}

class _TimeCards extends StatelessWidget {
  final TimeOfDay bedTime;
  final TimeOfDay wakeTime;
  final Widget bed;
  final Widget wake;

  const _TimeCards({
    required this.bedTime,
    required this.wakeTime,
    required this.bed,
    required this.wake,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppDimens.space12;
        final column = (constraints.maxWidth - gap) / 2;
        final room = column - _ScheduleTimeCard.chromeWidth;
        final style = _ScheduleTimeCard.timeStyle(context);
        final fits = [bedTime, wakeTime].every(
          (t) => FitText.fits(
            context,
            TextSpan(text: t.format(context), style: style),
            room,
          ),
        );
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bed,
              const SizedBox(height: AppDimens.space8),
              wake,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: bed),
            const SizedBox(width: gap),
            Expanded(child: wake),
          ],
        );
      },
    );
  }
}

/// Bed or wake time: a small icon and label over the time, the whole card
/// tappable for the time picker. Compact enough that two sit side by side
/// even at the largest text on a small phone.
class _ScheduleTimeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _ScheduleTimeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
    required this.onTap,
  });

  /// Everything in the card's width but the time: padding and border.
  static const double chromeWidth =
      AppDimens.space12 * 2 + AppDimens.borderThin * 2;

  static TextStyle? timeStyle(BuildContext context) =>
      context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return Semantics(
      button: true,
      label: '$title ${time.format(context)}, change',
      excludeSemantics: true,
      child: Material(
        color: v.glassFill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: v.glassBorder!),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: AppDimens.iconXs,
                      color: context.iconTint(iconColor),
                    ),
                    const SizedBox(width: AppDimens.space6),
                    Expanded(
                      child: Text(
                        title,
                        style: context.text.labelSmall?.copyWith(
                          color: v.grayText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/ui/edit.svg',
                      width: AppDimens.iconXs,
                      height: AppDimens.iconXs,
                      colorFilter: ColorFilter.mode(
                        v.grayText!,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.space4),
                Text(time.format(context), style: timeStyle(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dial: a 24-hour track with hour ticks and labels, the night as a
/// thick rounded band shading from night (bedtime) to morning (wake), and
/// two handles set inside the band's ends: flat circles in the sheet's
/// colour with a moon and a sun, the one being dragged a little larger with
/// a soft glow (the pattern of iOS Bedtime and other premium sleep apps).
class _SleepClockPainter extends CustomPainter {
  final double bedAngle;
  final double wakeAngle;
  final Color trackColor;
  final Color nightColor;
  final Color morningColor;
  final Color knobFill;
  final Color moonColor;
  final Color sunColor;
  final Color dialTextColor;
  final TextScaler textScaler;
  final _ActiveHandle active;

  _SleepClockPainter({
    required this.bedAngle,
    required this.wakeAngle,
    required this.trackColor,
    required this.nightColor,
    required this.morningColor,
    required this.knobFill,
    required this.moonColor,
    required this.sunColor,
    required this.dialTextColor,
    required this.textScaler,
    required this.active,
  });

  static const double _stroke = _CircularSleepClockPickerState._ringStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _CircularSleepClockPickerState._ringInset;
    final ring = Rect.fromCircle(center: center, radius: radius);

    // 24-hour track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );

    // Hour ticks inside the track, longer every 3 and 6 hours, and the four
    // quarter labels outside it.
    final tick = Paint()
      ..color = dialTextColor.withValues(alpha: 0.45)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: textScaler,
    );
    const labels = {0: '12A', 6: '6A', 12: '12P', 18: '6P'};
    for (var hour = 0; hour < 24; hour++) {
      final angle = hour / 24 * 2 * math.pi - math.pi / 2;
      final length = hour % 6 == 0 ? 10.0 : (hour % 3 == 0 ? 7.0 : 4.0);
      final outer = radius - _stroke / 2 - 4;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * outer,
        center + dir * (outer - length),
        tick,
      );
      if (labels[hour] case final text?) {
        label.text = TextSpan(
          text: text,
          style: AppTextStyles.small12.copyWith(
            color: dialTextColor,
            fontWeight: FontWeight.w600,
          ),
        );
        label.layout();
        final at = center + dir * (radius + _stroke / 2 + 12);
        label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
      }
    }
    label.dispose();

    // The night: bedtime to wake time, night colour shading to morning.
    var sweep = wakeAngle - bedAngle;
    if (sweep < 0) sweep += 2 * math.pi;
    // Angle the band's rounded end reaches past its centre line.
    final cap = _stroke / 2 / radius;
    canvas.drawArc(
      ring,
      bedAngle,
      sweep,
      false,
      Paint()
        // Starts a cap's width early and ends one late, so each rounded
        // end keeps its own colour instead of wrapping round to the other.
        ..shader = SweepGradient(
          endAngle: sweep + 2 * cap,
          colors: [nightColor, nightColor, morningColor, morningColor],
          stops: [
            0,
            cap / (sweep + 2 * cap),
            (cap + sweep) / (sweep + 2 * cap),
            1,
          ],
          transform: GradientRotation(bedAngle - cap),
        ).createShader(ring)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );

    _knob(
      canvas,
      center + Offset(math.cos(bedAngle), math.sin(bedAngle)) * radius,
      Icons.bedtime_rounded,
      moonColor,
      glow: nightColor,
      active: active == _ActiveHandle.bed || active == _ActiveHandle.arc,
    );
    _knob(
      canvas,
      center + Offset(math.cos(wakeAngle), math.sin(wakeAngle)) * radius,
      Icons.wb_sunny_rounded,
      sunColor,
      glow: morningColor,
      active: active == _ActiveHandle.wake || active == _ActiveHandle.arc,
    );
  }

  /// A handle inside the band's end: a flat circle in the sheet's colour
  /// with its icon; larger with a soft glow while dragged.
  void _knob(
    Canvas canvas,
    Offset at,
    IconData icon,
    Color iconColor, {
    required Color glow,
    required bool active,
  }) {
    final r = _stroke / 2 - 3 + (active ? 3 : 0);
    if (active) {
      canvas.drawCircle(
        at,
        r + 6,
        Paint()
          ..color = glow.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(at, r, Paint()..color = knobFill);
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: AppDimens.iconXs,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, at - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();
  }

  @override
  bool shouldRepaint(_SleepClockPainter old) =>
      old.bedAngle != bedAngle ||
      old.wakeAngle != wakeAngle ||
      old.active != active ||
      old.trackColor != trackColor ||
      old.nightColor != nightColor ||
      old.knobFill != knobFill ||
      old.dialTextColor != dialTextColor ||
      old.textScaler != textScaler;
}
