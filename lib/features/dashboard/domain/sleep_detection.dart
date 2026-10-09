import 'dart:math' as math;

import 'entities/sleep_session_info.dart';

/// Kinds of sleep sample a health store reports.
enum SleepStage { asleep, inBed, deep, rem, light, awake }

/// One health-store sleep sample, decoupled from the `health` package.
class SleepSample {
  final SleepStage stage;
  final DateTime from;
  final DateTime to;

  const SleepSample(this.stage, this.from, this.to);

  int get minutes => to.difference(from).inMinutes;
}

/// Samples further apart than this belong to different sessions (a night
/// and a nap, say).
const _sessionGap = Duration(hours: 2);

/// The main night among [samples] (all ending on one wake-up day): samples
/// are grouped into sessions and the longest one wins, so a nap never
/// stretches the night. Null when there are no samples.
SleepSessionInfo? buildHealthNight(List<SleepSample> samples) {
  if (samples.isEmpty) return null;
  final sorted = [...samples]..sort((a, b) => a.from.compareTo(b.from));

  final sessions = <List<SleepSample>>[];
  var end = sorted.first.to;
  for (final s in sorted) {
    if (sessions.isEmpty || s.from.isAfter(end.add(_sessionGap))) {
      sessions.add([s]);
      end = s.to;
    } else {
      sessions.last.add(s);
      if (s.to.isAfter(end)) end = s.to;
    }
  }

  Duration span(List<SleepSample> s) => s
      .map((e) => e.to)
      .reduce((a, b) => a.isAfter(b) ? a : b)
      .difference(s.first.from);
  final night = sessions.reduce((a, b) => span(b) > span(a) ? b : a);

  final totals = {for (final stage in SleepStage.values) stage: 0};
  var bed = night.first.from;
  var wake = night.first.to;
  for (final s in night) {
    totals[s.stage] = totals[s.stage]! + s.minutes;
    if (s.to.isAfter(wake)) wake = s.to;
  }

  // Prefer the most detailed figure the source gives: stages, then
  // "asleep", then time in bed, then the session's span.
  final deep = totals[SleepStage.deep]!;
  final rem = totals[SleepStage.rem]!;
  final light = totals[SleepStage.light]!;
  final awake = totals[SleepStage.awake]!;
  final staged = deep + rem + light;
  final asleep = totals[SleepStage.asleep]!;
  final inBed = totals[SleepStage.inBed]!;
  final minutes = staged > 0
      ? staged
      : asleep > 0
      ? asleep
      : inBed > 0
      ? inBed - awake
      : wake.difference(bed).inMinutes;

  return SleepSessionInfo(
    bedTime: bed,
    wakeTime: wake,
    duration: Duration(minutes: minutes.clamp(0, 24 * 60)),
    source: SleepDataSource.healthStore,
    deepSleepMinutes: deep > 0 ? deep : null,
    remSleepMinutes: rem > 0 ? rem : null,
    lightSleepMinutes: light > 0 ? light : null,
    awakeMinutes: awake > 0 ? awake : null,
  );
}

/// A screen turning on or off, from Android usage events.
class ScreenEvent {
  final DateTime time;
  final bool on;

  const ScreenEvent(this.time, {required this.on});
}

/// Tuning for [estimateSleepFromScreen].
class ScreenSleepRules {
  /// Screen-on moments up to this long (checking the time, a notification)
  /// don't end the night; they count as time awake.
  final Duration maxInterruption;

  /// Shortest screen-off stretch that counts as a night.
  final Duration minSleep;

  /// The night must end (wake-up) between these hours on the wake day.
  final int earliestWakeHour;
  final int latestWakeHour;

  /// And start no earlier than this hour the evening before.
  final int earliestBedHour;

  const ScreenSleepRules({
    this.maxInterruption = const Duration(minutes: 5),
    this.minSleep = const Duration(hours: 3),
    this.earliestWakeHour = 3,
    this.latestWakeHour = 14,
    this.earliestBedHour = 18,
  });
}

/// Estimates the night that ended on [wakeDay] from screen on/off [events]:
/// the longest stretch with the screen off, bridging brief check-ins.
/// Returns null when nothing looks like a night (e.g. still asleep, or the
/// phone was in use all night).
SleepSessionInfo? estimateSleepFromScreen(
  List<ScreenEvent> events, {
  required DateTime wakeDay,
  ScreenSleepRules rules = const ScreenSleepRules(),
}) {
  final day = DateTime(wakeDay.year, wakeDay.month, wakeDay.day);
  final windowStart = DateTime(
    day.year,
    day.month,
    day.day - 1,
    rules.earliestBedHour,
  );
  final earliestWake = day.add(Duration(hours: rules.earliestWakeHour));
  final latestWake = day.add(Duration(hours: rules.latestWakeHour));

  final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));

  // Screen-off gaps with a known start and end.
  final gaps = <({DateTime from, DateTime to})>[];
  DateTime? offAt;
  for (final e in sorted) {
    if (!e.on) {
      offAt ??= e.time;
    } else if (offAt != null) {
      gaps.add((from: offAt, to: e.time));
      offAt = null;
    }
  }

  // Merge gaps separated by short screen-on moments.
  final nights = <({DateTime from, DateTime to, int awakeMin})>[];
  for (final g in gaps) {
    if (g.from.isBefore(windowStart)) continue;
    final last = nights.isEmpty ? null : nights.last;
    if (last != null &&
        g.from.difference(last.to) <= rules.maxInterruption) {
      nights.last = (
        from: last.from,
        to: g.to,
        awakeMin: last.awakeMin + g.from.difference(last.to).inMinutes,
      );
    } else {
      nights.add((from: g.from, to: g.to, awakeMin: 0));
    }
  }

  final candidates = nights.where(
    (n) =>
        !n.to.isBefore(earliestWake) &&
        !n.to.isAfter(latestWake) &&
        n.to.difference(n.from) >= rules.minSleep,
  );
  if (candidates.isEmpty) return null;
  final best = candidates.reduce(
    (a, b) => b.to.difference(b.from) > a.to.difference(a.from) ? b : a,
  );

  final total = best.to.difference(best.from);
  return SleepSessionInfo(
    bedTime: best.from,
    wakeTime: best.to,
    duration: total - Duration(minutes: best.awakeMin),
    source: SleepDataSource.phone,
    awakeMinutes: best.awakeMin > 0 ? best.awakeMin : null,
  );
}

/// Bedtime consistency 0–100 from the spread (standard deviation) of
/// bedtimes: 30 min apart ≈ 90%, an hour ≈ 80%, two hours ≈ 60%.
int bedtimeConsistency(List<DateTime> bedTimes) {
  if (bedTimes.length < 2) return 90;
  // Minutes from noon, so 11 pm and 1 am sit close together.
  final minutes = [
    for (final t in bedTimes) (t.hour * 60 + t.minute - 12 * 60) % (24 * 60),
  ];
  final mean = minutes.reduce((a, b) => a + b) / minutes.length;
  final variance =
      minutes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) /
      minutes.length;
  final stdDev = math.sqrt(variance);
  return (100 - stdDev / 3).round().clamp(40, 100);
}

