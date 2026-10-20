import 'package:equatable/equatable.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';

/// Chart window on the trend detail pages.
enum TrendRange {
  /// Last 7 days, one bar a day.
  week(7, 'Daily'),

  /// Last 4 weeks, one bar a week ([TrendSeries.weekly]).
  month(28, 'Weekly'),

  /// Last 6 calendar months, one bar a month ([TrendSeries.monthly]). Only
  /// offered where change shows over months (weight). 186 days always
  /// covers the current month plus the 5 full months before it.
  halfYear(186, 'Monthly');

  final int days;
  final String label;
  const TrendRange(this.days, this.label);

  /// The ranges most trackers offer.
  static const standard = [week, month];

  /// Caption above the chart.
  String get caption => switch (this) {
    week => 'Last 7 days',
    month => 'Last 4 weeks',
    halfYear => 'Last 6 months',
  };
}

/// One day's value; null means nothing was logged (drawn as a gap, ignored
/// by averages) — different from a real zero.
class DailyPoint extends Equatable {
  final DateTime day;
  final double? value;

  const DailyPoint(this.day, this.value);

  @override
  List<Object?> get props => [day, value];
}

/// How a value relates to its goal.
enum GoalDirection {
  /// Reach at least the goal (water, steps).
  up,

  /// Lower is better (stress).
  down,

  /// Land close to the goal (calories vs plan, ±10%).
  near,
}

/// Per-day values for one metric, oldest first, ending today.
class TrendSeries extends Equatable {
  final List<DailyPoint> points;
  final double? goal;
  final GoalDirection direction;

  static const nearTolerance = 0.1;

  const TrendSeries(
    this.points, {
    this.goal,
    this.direction = GoalDirection.up,
  });

  /// Sums [values] per day over the last [days] days; days without an entry
  /// are null.
  static TrendSeries sum<T>({
    required int days,
    required Iterable<T> items,
    required DateTime Function(T) dateOf,
    required double Function(T) valueOf,
    double? goal,
    GoalDirection direction = GoalDirection.up,
    bool zeroWhenEmpty = false,
  }) {
    final buckets = bucketByDay(items, dateOf);
    return TrendSeries(
      [
        for (final day in lastNDays(days))
          DailyPoint(
            day,
            // A NaN / infinite entry (bad import) counts as nothing.
            buckets[day]?.fold<double>(0, (sum, i) {
                  final v = valueOf(i);
                  return v.isFinite ? sum + v : sum;
                }) ??
                (zeroWhenEmpty ? 0 : null),
          ),
      ],
      goal: goal,
      direction: direction,
    );
  }

  Iterable<double> get _values =>
      points.map((p) => p.value).whereType<double>().where((v) => v.isFinite);

  double? get today => points.isEmpty ? null : points.last.value;

  double? get average {
    final values = _values.toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? get best {
    final values = _values.toList();
    if (values.isEmpty) return null;
    return switch (direction) {
      GoalDirection.up => values.reduce((a, b) => a > b ? a : b),
      GoalDirection.down => values.reduce((a, b) => a < b ? a : b),
      GoalDirection.near when goal != null => values.reduce(
        (a, b) => (a - goal!).abs() <= (b - goal!).abs() ? a : b,
      ),
      GoalDirection.near => values.reduce((a, b) => a > b ? a : b),
    };
  }

  double get maxValue {
    final values = _values.toList();
    final top = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    return goal != null && goal! > top ? goal! : top;
  }

  int get loggedDays => _values.length;

  /// One point per 7 days, counted back from today (so the last week ends
  /// today); leftover older days are dropped. Each point is dated to its
  /// week's first day and holds the average of that week's logged days, so
  /// a daily [goal] still applies. Weeks with nothing logged are null.
  TrendSeries weekly() {
    final weeks = <DailyPoint>[];
    for (var end = points.length; end >= 7; end -= 7) {
      final week = points.sublist(end - 7, end);
      final values = week
          .map((p) => p.value)
          .whereType<double>()
          .where((v) => v.isFinite)
          .toList();
      weeks.insert(
        0,
        DailyPoint(
          week.first.day,
          values.isEmpty
              ? null
              : values.reduce((a, b) => a + b) / values.length,
        ),
      );
    }
    return TrendSeries(weeks, goal: goal, direction: direction);
  }

  /// One point per calendar month, the newest [months] that the series
  /// reaches; an older month the series only partly covers is dropped.
  /// Each point is dated to the month's 1st and holds the average of its
  /// logged days. Months with nothing logged are null.
  TrendSeries monthly({int months = 6}) {
    final byMonth = <DateTime, List<double>>{};
    final firstDay = points.isEmpty ? null : points.first.day;
    for (final p in points) {
      final month = DateTime(p.day.year, p.day.month);
      final list = byMonth.putIfAbsent(month, () => []);
      final v = p.value;
      if (v != null && v.isFinite) list.add(v);
    }
    // The oldest month is partial unless the series starts on its 1st.
    final partial = firstDay != null && firstDay.day != 1
        ? DateTime(firstDay.year, firstDay.month)
        : null;
    final keys = byMonth.keys.where((m) => m != partial).toList()..sort();
    final kept = keys.length > months
        ? keys.sublist(keys.length - months)
        : keys;
    return TrendSeries(
      [
        for (final m in kept)
          DailyPoint(
            m,
            byMonth[m]!.isEmpty
                ? null
                : byMonth[m]!.reduce((a, b) => a + b) / byMonth[m]!.length,
          ),
      ],
      goal: goal,
      direction: direction,
    );
  }

  int get daysMetGoal {
    final g = goal;
    if (g == null) return 0;
    return _values
        .where(
          (v) => switch (direction) {
            GoalDirection.up => v >= g,
            GoalDirection.down => v <= g,
            GoalDirection.near => (v - g).abs() <= g * nearTolerance,
          },
        )
        .length;
  }

  @override
  List<Object?> get props => [points, goal, direction];
}

/// A metric's daily series plus the raw entries behind it (newest first).
class TrendData<L> extends Equatable {
  final TrendSeries series;
  final List<L> logs;

  const TrendData(this.series, [this.logs = const []]);

  @override
  List<Object?> get props => [series, logs];
}
