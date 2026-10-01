import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// Turns a [HealthSnapshot] into the Health Analysis rows. Only rows backed
/// by real data are returned; every number comes from the snapshot.
class HealthAnalysisBuilder {
  const HealthAnalysisBuilder();

  List<HealthSignal> build(HealthSnapshot s, StressReport stress) {
    final rows = <HealthSignal>[];

    if (s.logsMeals) {
      final parts = ['Tracked ${s.mealsThisWeek} meal${_s(s.mealsThisWeek)}'];
      if (s.avgCaloriesPerDay != null) {
        parts.add('Avg ${s.avgCaloriesPerDay} cal/day');
      }
      rows.add(HealthSignal(
        kind: HealthSignalKind.diet,
        title: 'Diet & Nutrition',
        summary: parts.join(' · '),
        dataPoints: parts.length,
      ));
    }

    final metrics = _metrics(s);
    if (metrics != null) rows.add(metrics);

    if (s.sleepLastNightHours != null || s.sleepAvgHours != null) {
      final parts = <String>[
        if (s.sleepLastNightHours != null)
          '${_h(s.sleepLastNightHours!)}h last night',
        if (s.sleepAvgHours != null && s.sleepNightsLogged > 1)
          '${_h(s.sleepAvgHours!)}h avg',
      ];
      rows.add(HealthSignal(
        kind: HealthSignalKind.sleep,
        title: 'Sleep Analysis',
        summary: parts.join(' · '),
        dataPoints: parts.length,
      ));
    }

    final triggerCount = stress.triggers.length;
    rows.add(HealthSignal(
      kind: HealthSignalKind.stress,
      title: 'Stress Detection',
      summary: '${_level(stress.level)} · '
          '${triggerCount == 0 ? 'No triggers' : '$triggerCount trigger${_s(triggerCount)}'} today',
      dataPoints: 1 + triggerCount,
    ));

    final activity = <String>[
      if (s.stepsToday != null) '${_thousands(s.stepsToday!)} steps today',
      if (s.workoutsThisWeek > 0)
        '${s.workoutsThisWeek} workout${_s(s.workoutsThisWeek)} this week',
      if (s.distanceThisWeekKm >= 0.1)
        '${s.distanceThisWeekKm.toStringAsFixed(1)} km',
    ];
    if (activity.isNotEmpty) {
      rows.add(HealthSignal(
        kind: HealthSignalKind.activity,
        title: 'Activity',
        summary: activity.take(2).join(' · '),
        dataPoints: activity.length,
      ));
    }

    if (s.profile.hasMedicines) {
      rows.add(HealthSignal(
        kind: HealthSignalKind.medication,
        title: 'Medication',
        summary: 'From your profile: ${s.profile.medicines!.trim()}',
      ));
    }

    return rows;
  }

  HealthSignal? _metrics(HealthSnapshot s) {
    final v = s.vitals;
    final parts = <String>[
      if (v.avgHeartRate != null) 'HR avg ${v.avgHeartRate}bpm'
      else if (v.restingHeartRate != null) 'Resting HR ${v.restingHeartRate}bpm',
      if (v.systolic != null && v.diastolic != null) 'BP ${v.systolic}/${v.diastolic}',
      if (v.spo2Percent != null) 'SpO2 ${v.spo2Percent}%',
      if (v.hrvMs != null) 'HRV ${v.hrvMs!.round()}ms',
    ];
    if (parts.isNotEmpty) {
      return HealthSignal(
        kind: HealthSignalKind.metrics,
        title: 'Health Metrics',
        summary: parts.take(3).join(' · '),
        dataPoints: parts.length,
      );
    }
    final p = s.profile;
    if (p.bloodPressureTop != null && p.bloodPressureBottom != null) {
      return HealthSignal(
        kind: HealthSignalKind.metrics,
        title: 'Health Metrics',
        summary: 'From your profile: BP ${p.bloodPressureTop}/${p.bloodPressureBottom}',
      );
    }
    return null;
  }

  static String _level(StressLevel level) => switch (level) {
        StressLevel.low => 'Low stress',
        StressLevel.moderate => 'Moderate stress',
        StressLevel.high => 'High stress',
      };

  static String _s(int n) => n == 1 ? '' : 's';
  static String _h(double hours) => hours.toStringAsFixed(1);
  static String _thousands(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
}
