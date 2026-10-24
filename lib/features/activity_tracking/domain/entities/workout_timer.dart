import 'dart:convert';

import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';

/// A workout being timed (no GPS). Kept as wall-clock times rather than a
/// running counter, so it survives the app being closed or killed without a
/// foreground service: reopening works the elapsed time out again.
class WorkoutTimer {
  final ActivityType type;
  final DateTime startedAt;

  /// Active time before the current run (all earlier runs between pauses).
  final Duration banked;

  /// When the current run started; null while paused.
  final DateTime? runningSince;

  const WorkoutTimer({
    required this.type,
    required this.startedAt,
    this.banked = Duration.zero,
    this.runningSince,
  });

  factory WorkoutTimer.start(ActivityType type, DateTime now) =>
      WorkoutTimer(type: type, startedAt: now, runningSince: now);

  bool get isRunning => runningSince != null;

  /// Active time at [now], never negative (a clock set back) and never past
  /// [WorkoutLogRules.maxLength].
  Duration elapsed(DateTime now) {
    final since = runningSince;
    var total = banked;
    if (since != null && now.isAfter(since)) total += now.difference(since);
    return total > WorkoutLogRules.maxLength
        ? WorkoutLogRules.maxLength
        : total;
  }

  /// Whether the timer has reached [WorkoutLogRules.maxLength].
  bool isAtLimit(DateTime now) => elapsed(now) >= WorkoutLogRules.maxLength;

  WorkoutTimer pause(DateTime now) => isRunning
      ? WorkoutTimer(type: type, startedAt: startedAt, banked: elapsed(now))
      : this;

  WorkoutTimer resume(DateTime now) => isRunning
      ? this
      : WorkoutTimer(
          type: type,
          startedAt: startedAt,
          banked: banked,
          runningSince: now,
        );

  String encode() => jsonEncode({
    'type': type.name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'bankedSeconds': banked.inSeconds,
    'runningSince': runningSince?.millisecondsSinceEpoch,
  });

  /// The timer saved by [encode], or null when missing or unreadable.
  static WorkoutTimer? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final banked = (json['bankedSeconds'] as num).toInt();
      final running = json['runningSince'] as num?;
      if (banked < 0) return null;
      return WorkoutTimer(
        type: ActivityType.fromName(json['type'] as String?),
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['startedAt'] as num).toInt(),
        ),
        banked: Duration(seconds: banked),
        runningSince: running == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(running.toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}
