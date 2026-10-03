import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';

TrendSeries _series(
  List<double?> values, {
  double? goal,
  GoalDirection direction = GoalDirection.up,
}) {
  // Monday 5 Jan 2026 onwards, so weekdays/weekends are predictable.
  final start = DateTime(2026, 1, 5);
  return TrendSeries(
    [
      for (var i = 0; i < values.length; i++)
        DailyPoint(DateTime(start.year, start.month, start.day + i), values[i]),
    ],
    goal: goal,
    direction: direction,
  );
}

String _f(double v) => '${v.round()}';

void main() {
  test('asks for more data with fewer than two logged days', () {
    final insights = seriesInsights(
      _series([null, null, 5]),
      format: _f,
      noun: 'water',
    );
    expect(insights, hasLength(1));
    expect(insights.single.text, contains('Log water'));
  });

  test('reports goal hit rate and the current streak', () {
    final insights = seriesInsights(
      _series([1, 1, 3, 3, 3], goal: 3),
      format: _f,
      noun: 'water',
    );
    final goal = insights.firstWhere((i) => i.icon == Icons.flag_rounded);
    expect(goal.text, contains('3-day goal streak'));
    expect(goal.text, contains('3 of the last 5 days'));
  });

  test('a rising "less is better" metric is flagged, not praised', () {
    final insights = seriesInsights(
      _series(
        [100, 100, 100, 200, 200, 200],
        direction: GoalDirection.down,
      ),
      format: _f,
      noun: 'screen time',
    );
    final trend = insights.firstWhere(
      (i) => i.icon == Icons.trending_up_rounded,
    );
    expect(trend.text, contains('Up 100%'));
    expect(trend.text, contains('Worth keeping an eye on'));
  });

  test('compares weekends with weekdays when they differ', () {
    // Mon–Fri 1000, Sat–Sun 2000.
    final insights = seriesInsights(
      _series([1000, 1000, 1000, 1000, 1000, 2000, 2000]),
      format: _f,
      noun: 'water',
    );
    expect(
      insights.map((i) => i.text),
      contains(contains('Weekends average 2000, 100% more')),
    );
  });
}
