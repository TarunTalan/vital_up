import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';

/// A 24-hour clock for a night's sleep: drag the moon (bedtime) or the sun
/// (wake time), or drag the arc between them to move the whole night and
/// keep its length. Snaps to 5 minutes with a light haptic tick. The middle
/// shows how long that is and how it compares with the sleep [goal].
class CircularSleepClockPicker extends StatefulWidget {
  final TimeOfDay initialBedTime;
  final TimeOfDay initialWakeTime;
  final ValueChanged<TimeOfDay>? onBedTimeChanged;
  final ValueChanged<TimeOfDay>? onWakeTimeChanged;
  final void Function(TimeOfDay bed, TimeOfDay wake)? onChanged;

  /// Nightly sleep goal: the middle says "Goal met" or how far short.
  final Duration? goal;

  const CircularSleepClockPicker({
    super.key,
    this.initialBedTime = const TimeOfDay(hour: 23, minute: 0),
    this.initialWakeTime = const TimeOfDay(hour: 7, minute: 0),
    this.onBedTimeChanged,
    this.onWakeTimeChanged,
    this.onChanged,
    this.goal,
  });

  @override
  State<CircularSleepClockPicker> createState() =>
      _CircularSleepClockPickerState();
}

class _CircularSleepClockPickerState extends State<CircularSleepClockPicker> {
  late TimeOfDay _bedTime;
  late TimeOfDay _wakeTime;
  _ActiveHandle _activeHandle = _ActiveHandle.none;

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

  /// "45m", "1h 10m", "8h".
  static String _short(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Duration _getSleepDuration() {
    final bedMinutes = _bedTime.hour * 60 + _bedTime.minute;
    var wakeMinutes = _wakeTime.hour * 60 + _wakeTime.minute;
    if (wakeMinutes < bedMinutes) {
      wakeMinutes += 24 * 60;
    }
    return Duration(minutes: wakeMinutes - bedMinutes);
  }

  void _onPanStart(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 24;

    final bedAngle = _timeToAngle(_bedTime);
    final wakeAngle = _timeToAngle(_wakeTime);

    final bedPos = Offset(
      center.dx + radius * math.cos(bedAngle),
      center.dy + radius * math.sin(bedAngle),
    );
    final wakePos = Offset(
      center.dx + radius * math.cos(wakeAngle),
      center.dy + radius * math.sin(wakeAngle),
    );

    final distToBed = (localPosition - bedPos).distance;
    final distToWake = (localPosition - wakePos).distance;

    const hitRadius = 38.0;

    if (distToBed < hitRadius && distToBed <= distToWake) {
      _activeHandle = _ActiveHandle.bed;
      HapticFeedback.selectionClick();
    } else if (distToWake < hitRadius) {
      _activeHandle = _ActiveHandle.wake;
      HapticFeedback.selectionClick();
    } else if (_onArc(localPosition, center, radius)) {
      // Grabbing the arc itself moves the whole night.
      _activeHandle = _ActiveHandle.arc;
      _arcStartAngle = math.atan2(
        localPosition.dy - center.dy,
        localPosition.dx - center.dx,
      );
      _arcStartBed = _bedTime;
      _arcStartWake = _wakeTime;
      HapticFeedback.selectionClick();
    } else {
      _activeHandle = _ActiveHandle.none;
    }
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
      if (_bedTime != newTime) {
        setState(() => _bedTime = newTime);
        widget.onBedTimeChanged?.call(newTime);
        widget.onChanged?.call(_bedTime, _wakeTime);
        HapticFeedback.lightImpact();
      }
    } else if (_activeHandle == _ActiveHandle.wake) {
      if (_wakeTime != newTime) {
        setState(() => _wakeTime = newTime);
        widget.onWakeTimeChanged?.call(newTime);
        widget.onChanged?.call(_bedTime, _wakeTime);
        HapticFeedback.lightImpact();
      }
    }
  }

  void _onPanEnd() {
    _activeHandle = _ActiveHandle.none;
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

  static const double _ringStroke = 26;

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final duration = _getSleepDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final goal = widget.goal;
    final goalMet = goal != null && duration >= goal;
    final goalNote = goal == null
        ? null
        : goalMet
        ? 'Goal met'
        : '${_short(goal - duration)} under your ${_short(goal)} goal';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final clockSize = math.min(constraints.maxWidth, 280.0);
            return SizedBox(
              width: clockSize,
              height: clockSize,
              child: GestureDetector(
                onPanStart: (details) => _onPanStart(
                  details.localPosition,
                  Size(clockSize, clockSize),
                ),
                onPanUpdate: (details) => _onPanUpdate(
                  details.localPosition,
                  Size(clockSize, clockSize),
                ),
                onPanEnd: (_) => _onPanEnd(),
                child: CustomPaint(
                  size: Size(clockSize, clockSize),
                  painter: _SleepClockPainter(
                    bedAngle: _timeToAngle(_bedTime),
                    wakeAngle: _timeToAngle(_wakeTime),
                    trackColor: v.track ?? Colors.grey.withAlpha(50),
                    arcColor: AppColors.sleep,
                    dialTextColor: v.grayText ?? Colors.grey,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.space24),
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
        const SizedBox(height: AppDimens.space16),
        // Bottom interactive cards showing Bed & Wake times
        Row(
          children: [
            Expanded(
              child: _ScheduleTimeCard(
                icon: Icons.bedtime_rounded,
                iconColor: AppColors.sleep,
                title: 'Bedtime',
                time: _bedTime,
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _bedTime,
                  );
                  if (t != null) {
                    setState(() => _bedTime = t);
                    widget.onBedTimeChanged?.call(t);
                    widget.onChanged?.call(_bedTime, _wakeTime);
                  }
                },
              ),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: _ScheduleTimeCard(
                icon: Icons.wb_sunny_rounded,
                iconColor: AppColors.warning,
                title: 'Wake up',
                time: _wakeTime,
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _wakeTime,
                  );
                  if (t != null) {
                    setState(() => _wakeTime = t);
                    widget.onWakeTimeChanged?.call(t);
                    widget.onChanged?.call(_bedTime, _wakeTime);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ActiveHandle { none, bed, wake, arc }

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

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Material(
      color: v.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        side: BorderSide(color: v.glassBorder!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space12,
            vertical: AppDimens.space12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimens.space6),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: AppDimens.iconSm, color: iconColor),
              ),
              const SizedBox(width: AppDimens.space10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      time.format(context),
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/ui/edit.svg',
                width: AppDimens.iconXs,
                height: AppDimens.iconXs,
                colorFilter: ColorFilter.mode(v.grayText!, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepClockPainter extends CustomPainter {
  final double bedAngle;
  final double wakeAngle;
  final Color trackColor;
  final Color arcColor;
  final Color dialTextColor;
  final TextScaler textScaler;

  _SleepClockPainter({
    required this.bedAngle,
    required this.wakeAngle,
    required this.trackColor,
    required this.arcColor,
    required this.dialTextColor,
    required this.textScaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 24;
    const strokeWidth = _CircularSleepClockPickerState._ringStroke;

    // 1. Draw outer 24-hour background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw 24-hour markers & hour labels
    final markerPaint = Paint()
      ..color = dialTextColor.withAlpha(100)
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: textScaler,
    );

    const labels = {0: '12A', 6: '6A', 12: '12P', 18: '6P'};

    for (int hour = 0; hour < 24; hour++) {
      final angle = (hour / 24.0) * 2 * math.pi - (math.pi / 2);
      final isMajor = hour % 6 == 0;
      final isQuarter = hour % 3 == 0;

      final innerR = radius - (isMajor ? 12 : (isQuarter ? 8 : 4));
      final outerR = radius - (strokeWidth / 2) - 2;

      final p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, markerPaint);

      if (labels.containsKey(hour)) {
        textPainter.text = TextSpan(
          text: labels[hour],
          style: AppTextStyles.small12.copyWith(
            color: dialTextColor,
            fontWeight: FontWeight.w700,
          ),
        );
        textPainter.layout();
        final textRadius = radius + (strokeWidth / 2) + 12;
        final textPos = Offset(
          center.dx + textRadius * math.cos(angle) - (textPainter.width / 2),
          center.dy + textRadius * math.sin(angle) - (textPainter.height / 2),
        );
        textPainter.paint(canvas, textPos);
      }
    }

    // 3. Draw active sleep arc from bedAngle clockwise to wakeAngle
    var sweepAngle = wakeAngle - bedAngle;
    if (sweepAngle < 0) {
      sweepAngle += 2 * math.pi;
    }

    final arcGradient = SweepGradient(
      startAngle: bedAngle,
      endAngle: bedAngle + sweepAngle,
      colors: [arcColor, AppColors.teal, AppColors.primary],
      transform: GradientRotation(bedAngle),
    );

    final arcPaint = Paint()
      ..shader = arcGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      bedAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 4. Draw Bedtime Knob (🌙 Moon handle)
    final bedPos = Offset(
      center.dx + radius * math.cos(bedAngle),
      center.dy + radius * math.sin(bedAngle),
    );
    _drawKnob(
      canvas,
      bedPos,
      AppColors.sleep,
      Icons.bedtime_rounded,
      Colors.white,
    );

    // 5. Draw Wake-up Knob (☀️ Sun handle)
    final wakePos = Offset(
      center.dx + radius * math.cos(wakeAngle),
      center.dy + radius * math.sin(wakeAngle),
    );
    _drawKnob(
      canvas,
      wakePos,
      AppColors.warning,
      Icons.wb_sunny_rounded,
      Colors.white,
    );
  }

  void _drawKnob(
    Canvas canvas,
    Offset position,
    Color color,
    IconData icon,
    Color iconColor,
  ) {
    const knobRadius = 18.0;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(position.translate(0, 2), knobRadius, shadowPaint);

    // Outer ring
    final knobPaint = Paint()..color = color;
    canvas.drawCircle(position, knobRadius, knobPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(position, knobRadius, borderPaint);

    // Icon in knob
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: AppDimens.iconXs,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: iconColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SleepClockPainter oldDelegate) {
    return oldDelegate.bedAngle != bedAngle ||
        oldDelegate.wakeAngle != wakeAngle ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.dialTextColor != dialTextColor ||
        oldDelegate.textScaler != textScaler;
  }
}
