import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// Today's stress score (0 calm – 100 very stressed) from the user's
/// check-in and lifestyle triggers (sleep, screen time, meals, hydration,
/// activity). Pure and deterministic so it can be unit-tested.
class StressEstimator {
  const StressEstimator();

  /// Score with no check-in and no triggers.
  static const int baseline = 15;

  StressReport estimate({
    required HealthSnapshot snapshot,
    StressCheckIn? checkIn,
    int? yesterdayScore,
  }) {
    final triggers = detectTriggers(snapshot);
    final proxy =
        (baseline + triggers.fold<int>(0, (sum, t) => sum + t.severity.weight))
            .clamp(0, 100);
    final self = checkIn == null ? null : (checkIn.level - 1) * 25;

    final int score;
    final StressSource source;
    if (self != null) {
      score = (0.7 * self + 0.3 * proxy).round();
      source = StressSource.checkIn;
    } else {
      score = proxy;
      source = StressSource.estimated;
    }

    final clamped = score.clamp(0, 100);
    return StressReport(
      score: clamped,
      level: StressLevel.fromScore(clamped),
      source: source,
      trend: trendText(clamped, yesterdayScore),
      triggers: triggers,
      todayCheckIn: checkIn,
    );
  }

  List<StressTrigger> detectTriggers(HealthSnapshot s) {
    final triggers = <StressTrigger>[];
    final hour = s.takenAt.hour;

    final sleep = s.sleepLastNightHours;
    if (sleep != null && sleep < 7) {
      triggers.add(
        StressTrigger(
          name: 'Sleep deficit',
          severity: sleep < 6 ? TriggerSeverity.high : TriggerSeverity.medium,
        ),
      );
    }

    final screen = s.screenTimeTodayMinutes;
    if (screen != null && screen >= 240) {
      triggers.add(
        StressTrigger(
          name: 'High screen time',
          severity: screen >= 360
              ? TriggerSeverity.high
              : TriggerSeverity.medium,
        ),
      );
    }

    // Only judge hydration for users who actually log water, against the
    // share of the goal expected by now (07:00–22:00 drinking window).
    final waterGoal = s.waterGoalMl;
    if (s.tracksWater && waterGoal != null && hour >= 11) {
      final expected = waterGoal * ((hour - 7).clamp(0, 15) / 15);
      final ratio = expected <= 0 ? 1.0 : (s.waterTodayMl ?? 0) / expected;
      if (ratio < 0.75) {
        triggers.add(
          StressTrigger(
            name: 'Low hydration',
            severity: ratio < 0.5
                ? TriggerSeverity.medium
                : TriggerSeverity.low,
          ),
        );
      }
    }

    if (s.logsMeals) {
      final missedMeals =
          (hour >= 14 && s.mealsToday == 0) || (hour >= 21 && s.mealsToday < 2);
      final sparseWeek =
          s.daysWithMealsThisWeek >= 3 &&
          s.mealsThisWeek / s.daysWithMealsThisWeek < 2;
      if (missedMeals || sparseWeek) {
        triggers.add(
          StressTrigger(
            name: 'Irregular meals',
            severity: missedMeals
                ? TriggerSeverity.high
                : TriggerSeverity.medium,
          ),
        );
      }
    }

    // Without step data we can't tell "inactive" from "doesn't track".
    final steps = s.stepsToday;
    if (steps != null && hour >= 18 && steps < 3000) {
      triggers.add(
        const StressTrigger(
          name: 'Low activity',
          severity: TriggerSeverity.low,
        ),
      );
    }

    // Most severe first.
    triggers.sort((a, b) => b.severity.weight.compareTo(a.severity.weight));
    return triggers;
  }

  String trendText(int today, int? yesterday) {
    if (yesterday == null) return 'First reading — check back tomorrow';
    final diff = today - yesterday;
    if (diff > 5) return 'Higher than yesterday';
    if (diff < -5) return 'Lower than yesterday';
    return 'Similar to yesterday';
  }
}
