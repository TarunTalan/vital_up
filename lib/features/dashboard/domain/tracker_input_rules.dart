import 'package:vital_up/core/utils/input_rules.dart';

/// Pure checks for what users type or pick on the dashboard trackers, kept
/// apart from the widgets so they can be unit tested.

/// Progress of [value] towards [goal] (1 = goal reached), or null when
/// there's no usable goal or the maths would give NaN / infinity.
double? safeFraction(num? value, num? goal) {
  if (value == null || goal == null || goal <= 0) return null;
  final f = value / goal;
  return f.isFinite ? f : null;
}

// ---------------------------------------------------------------------------
// Water
// ---------------------------------------------------------------------------

/// Digits allowed in the custom water amount field ("5000").
const waterAmountMaxDigits = 4;

/// The typed custom water amount in ml, or null when it isn't a whole
/// number within [InputLimits.waterMlMin]..[InputLimits.waterMlMax].
int? parseWaterAmount(String text) {
  final value = parseNumberInRange(
    text,
    min: InputLimits.waterMlMin,
    max: InputLimits.waterMlMax,
  );
  if (value == null || value != value.roundToDouble()) return null;
  return value.toInt();
}

const waterAmountError =
    'Enter ${InputLimits.waterMlMin} to ${InputLimits.waterMlMax} ml.';

/// A stored daily water goal, falling back to [fallback] when it is
/// missing or outside the allowed range (e.g. corrupted storage).
int sanitizeWaterGoal(int? ml, {required int fallback}) =>
    ml != null &&
        ml >= InputLimits.waterGoalMlMin &&
        ml <= InputLimits.waterGoalMlMax
    ? ml
    : fallback;

// ---------------------------------------------------------------------------
// Sleep
// ---------------------------------------------------------------------------

/// Shortest and longest night a user can log by hand.
const minSleepEntry = Duration(minutes: 30);
const maxSleepEntry = Duration(hours: 18);

/// A wake-up time this far past "now" is still accepted (clock drift, a
/// minute spent on the dial).
const _futureSlack = Duration(minutes: 5);

/// A stored nightly sleep goal in minutes, falling back to [fallback] when
/// missing or outside [InputLimits.sleepGoalMinMin]..[InputLimits.sleepGoalMinMax].
int sanitizeSleepGoal(int? minutes, {required int fallback}) =>
    minutes != null &&
        minutes >= InputLimits.sleepGoalMinMin &&
        minutes <= InputLimits.sleepGoalMinMax
    ? minutes
    : fallback;

/// Bed and wake times for a night that ended on [wakeDay], from minutes
/// after midnight on the dial. A bedtime at or after the wake time is the
/// evening before. Built from calendar fields, so DST days stay correct.
({DateTime bed, DateTime wake}) sleepEntryTimes(
  DateTime wakeDay, {
  required int bedMinutes,
  required int wakeMinutes,
}) {
  final wake = DateTime(
    wakeDay.year,
    wakeDay.month,
    wakeDay.day,
    wakeMinutes ~/ 60,
    wakeMinutes % 60,
  );
  var bed = DateTime(
    wakeDay.year,
    wakeDay.month,
    wakeDay.day,
    bedMinutes ~/ 60,
    bedMinutes % 60,
  );
  if (!bed.isBefore(wake)) {
    bed = DateTime(
      wakeDay.year,
      wakeDay.month,
      wakeDay.day - 1,
      bedMinutes ~/ 60,
      bedMinutes % 60,
    );
  }
  return (bed: bed, wake: wake);
}

/// Why a hand-entered night can't be saved, or null when it can.
String? sleepEntryError(DateTime bed, DateTime wake, {required DateTime now}) {
  if (wake.isAfter(now.add(_futureSlack))) {
    return "Wake-up time can't be in the future.";
  }
  final slept = wake.difference(bed);
  if (slept < minSleepEntry) return 'Sleep must be at least 30 minutes.';
  if (slept > maxSleepEntry) return 'Sleep can be at most 18 hours.';
  return null;
}

// ---------------------------------------------------------------------------
// Screen time
// ---------------------------------------------------------------------------

/// Allowed daily screen time limit, in minutes.
const screenLimitMinMinutes = 15;
const screenLimitMaxMinutes = 24 * 60;

int sanitizeScreenLimit(int? minutes, {required int fallback}) =>
    minutes != null &&
        minutes >= screenLimitMinMinutes &&
        minutes <= screenLimitMaxMinutes
    ? minutes
    : fallback;
