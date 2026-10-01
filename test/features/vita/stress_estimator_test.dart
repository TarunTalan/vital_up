import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/services/health_analysis_builder.dart';
import 'package:vital_up/features/vita/domain/services/stress_estimator.dart';

HealthSnapshot _snapshot({
  int hour = 20,
  double? sleep,
  int? screenMinutes,
  bool tracksWater = false,
  int? waterMl,
  int mealsToday = 0,
  int mealsWeek = 0,
  int mealDays = 0,
  int? steps,
  VitalsSnapshot vitals = const VitalsSnapshot(),
  ProfileSnapshot profile = const ProfileSnapshot(),
}) =>
    HealthSnapshot(
      takenAt: DateTime(2026, 10, 1, hour),
      profile: profile,
      sleepLastNightHours: sleep,
      screenTimeTodayMinutes: screenMinutes,
      tracksWater: tracksWater,
      waterTodayMl: waterMl,
      mealsToday: mealsToday,
      mealsThisWeek: mealsWeek,
      daysWithMealsThisWeek: mealDays,
      stepsToday: steps,
      vitals: vitals,
    );

void main() {
  const estimator = StressEstimator();

  group('detectTriggers', () {
    test('no data means no triggers, not false alarms', () {
      expect(estimator.detectTriggers(_snapshot()), isEmpty);
    });

    test('flags sleep deficit by severity', () {
      final short = estimator.detectTriggers(_snapshot(sleep: 5.5));
      expect(short.single.name, 'Sleep deficit');
      expect(short.single.severity, TriggerSeverity.high);

      final medium = estimator.detectTriggers(_snapshot(sleep: 6.5));
      expect(medium.single.severity, TriggerSeverity.medium);

      expect(estimator.detectTriggers(_snapshot(sleep: 7.5)), isEmpty);
    });

    test('only judges hydration for users who log water', () {
      expect(
        estimator.detectTriggers(_snapshot(hour: 18, waterMl: 0)),
        isEmpty,
      );
      final low = estimator.detectTriggers(
        _snapshot(hour: 18, tracksWater: true, waterMl: 200),
      );
      expect(low.single.name, 'Low hydration');
    });

    test('missed meals only for users who log meals', () {
      expect(estimator.detectTriggers(_snapshot(hour: 15)), isEmpty);
      final missed = estimator.detectTriggers(
        _snapshot(hour: 15, mealsWeek: 12, mealDays: 4),
      );
      expect(missed.single.name, 'Irregular meals');
      expect(missed.single.severity, TriggerSeverity.high);
    });

    test('sorts most severe first', () {
      final triggers = estimator.detectTriggers(
        _snapshot(sleep: 6.5, screenMinutes: 400, steps: 1000),
      );
      expect(triggers.map((t) => t.severity).toList(), [
        TriggerSeverity.high,
        TriggerSeverity.medium,
        TriggerSeverity.low,
      ]);
    });
  });

  group('estimate', () {
    test('calm day without data is low and marked as an estimate', () {
      final report = estimator.estimate(snapshot: _snapshot());
      expect(report.score, StressEstimator.baseline);
      expect(report.level, StressLevel.low);
      expect(report.source, StressSource.estimated);
      expect(report.trend, contains('First reading'));
    });

    test('check-in dominates lifestyle signals', () {
      final report = estimator.estimate(
        snapshot: _snapshot(),
        checkIn: StressCheckIn(date: DateTime(2026, 10, 1), level: 5),
      );
      expect(report.source, StressSource.checkIn);
      expect(report.level, StressLevel.high);
    });

    test('HRV well below baseline raises the wearable score', () {
      final vitals = const VitalsSnapshot(hrvMs: 30, hrvBaselineMs: 50);
      expect(estimator.wearableScore(vitals), greaterThan(65));
      final report = estimator.estimate(snapshot: _snapshot(vitals: vitals));
      expect(report.source, StressSource.wearable);
      expect(
        report.triggers.map((t) => t.name),
        contains('Lower heart-rate variability'),
      );
    });

    test('wearable score is null without a baseline', () {
      expect(
        estimator.wearableScore(const VitalsSnapshot(hrvMs: 40)),
        isNull,
      );
    });

    test('trend compares with yesterday', () {
      expect(estimator.trendText(60, 40), 'Higher than yesterday');
      expect(estimator.trendText(40, 60), 'Lower than yesterday');
      expect(estimator.trendText(42, 40), 'Similar to yesterday');
    });
  });

  group('HealthAnalysisBuilder', () {
    const builder = HealthAnalysisBuilder();

    test('only shows rows backed by data (stress always present)', () {
      final snapshot = _snapshot();
      final rows = builder.build(snapshot, estimator.estimate(snapshot: snapshot));
      expect(rows.map((r) => r.kind), [HealthSignalKind.stress]);
    });

    test('builds diet, sleep, metrics and medication rows from real data', () {
      final snapshot = HealthSnapshot(
        takenAt: DateTime(2026, 10, 1, 20),
        mealsThisWeek: 18,
        daysWithMealsThisWeek: 7,
        avgCaloriesPerDay: 1840,
        sleepLastNightHours: 6.2,
        stepsToday: 7240,
        vitals: const VitalsSnapshot(avgHeartRate: 72, spo2Percent: 98),
        profile: const ProfileSnapshot(medicines: 'Metformin'),
      );
      final rows = builder.build(snapshot, estimator.estimate(snapshot: snapshot));
      final byKind = {for (final r in rows) r.kind: r.summary};

      expect(byKind[HealthSignalKind.diet], 'Tracked 18 meals · Avg 1840 cal/day');
      expect(byKind[HealthSignalKind.metrics], 'HR avg 72bpm · SpO2 98%');
      expect(byKind[HealthSignalKind.sleep], '6.2h last night');
      expect(byKind[HealthSignalKind.activity], '7,240 steps today');
      expect(byKind[HealthSignalKind.medication], 'From your profile: Metformin');
    });

    test('ignores "none" profile answers', () {
      final snapshot = _snapshot(profile: const ProfileSnapshot(medicines: 'None'));
      final rows = builder.build(snapshot, estimator.estimate(snapshot: snapshot));
      expect(rows.any((r) => r.kind == HealthSignalKind.medication), isFalse);
    });
  });

  test('snapshot JSON drops missing data', () {
    final json = _snapshot(sleep: 7).toJson();
    expect(json['sleep'], {'lastNightHours': 7.0, 'nightsLogged': 0});
    expect(json.containsKey('hydration'), isFalse);
    expect(json.containsKey('screenTimeTodayMinutes'), isFalse);
  });
}
