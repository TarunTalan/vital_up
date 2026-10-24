import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';

/// A timed workout's goal: minutes ([WorkoutTargetType.duration]) or
/// calories.
typedef TimerTarget = ({WorkoutTargetType type, double value});

/// How often the coach gives the time and calories.
const timerCueEvery = Duration(minutes: 5);

/// What the voice coach says between two looks at a timed workout's clock
/// ([before] → [now] of active time, with the calories at each), or null.
/// One cue at a time, most important first: the goal reached, halfway to
/// it, then every [timerCueEvery] the time so far, calories and what's
/// left of the goal.
String? timerCue({
  required Duration before,
  required Duration now,
  required int caloriesBefore,
  required int caloriesNow,
  TimerTarget? target,
}) {
  if (now <= before) return null;
  if (target != null && target.value > 0) {
    double progress(Duration time, int calories) =>
        (target.type == WorkoutTargetType.duration
            ? time.inSeconds / 60
            : calories) /
        target.value;
    final was = progress(before, caloriesBefore);
    final reached = progress(now, caloriesNow);
    final goal = _goalLabel(target);
    if (was < 1 && reached >= 1) return 'Goal reached. $goal. Great work.';
    if (was < 0.5 && reached >= 0.5 && reached < 1) {
      final size = target.type == WorkoutTargetType.duration
          ? '${target.value.round()}-minute'
          : '${target.value.round()}-calorie';
      return 'Halfway to your $size goal.';
    }
  }
  final every = timerCueEvery.inMinutes;
  if (now.inMinutes ~/ every > before.inMinutes ~/ every &&
      now.inMinutes >= every) {
    final minutes = now.inMinutes ~/ every * every;
    final buffer = StringBuffer('${_minutes(minutes)}. ');
    buffer.write('About $caloriesNow calories.');
    final left = _left(target, minutes, caloriesNow);
    if (left != null) buffer.write(' $left');
    return buffer.toString();
  }
  return null;
}

/// "30 minutes", "200 calories".
String _goalLabel(TimerTarget target) =>
    target.type == WorkoutTargetType.duration
    ? _minutes(target.value.round())
    : '${target.value.round()} calories';

String _minutes(int minutes) {
  if (minutes < 60) return minutes == 1 ? '1 minute' : '$minutes minutes';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final h = hours == 1 ? '1 hour' : '$hours hours';
  return rest == 0 ? h : '$h ${_minutes(rest)}';
}

/// "20 minutes to your goal." while it isn't reached.
String? _left(TimerTarget? target, int minutes, int calories) {
  if (target == null || target.value <= 0) return null;
  if (target.type == WorkoutTargetType.duration) {
    final left = target.value.round() - minutes;
    return left > 0 ? '${_minutes(left)} to your goal.' : null;
  }
  final left = target.value.round() - calories;
  return left > 0 ? '$left calories to your goal.' : null;
}
