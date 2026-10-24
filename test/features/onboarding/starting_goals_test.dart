import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/features/activity_goals/data/datasources/activity_goals_local_datasource.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/onboarding/data/starting_goals_writer.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/usecases/starting_goals.dart';

/// Goals kept in prefs like the real repository; progress isn't needed.
class FakeActivityGoals implements ActivityGoalsRepository {
  final ActivityGoalsLocalDataSource local;

  FakeActivityGoals(SharedPreferences prefs)
    : local = ActivityGoalsLocalDataSource(prefs);

  @override
  List<ActivityGoal> getGoals() => local.read();

  @override
  bool get hasSavedGoals => local.hasSaved;

  @override
  Future<void> saveGoal(ActivityGoal goal) => local.write([
    for (final g in local.read())
      if (g.id != goal.id) g,
    goal,
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real services on [prefs]; goal reads and writes never touch Isar.
StartingGoalsWriter goalsWriter(SharedPreferences prefs) => StartingGoalsWriter(
  water: WaterIntakeService(IsarService(), prefs),
  sleep: SleepService(IsarService(), prefs),
  screenTime: ScreenTimeService(prefs),
  activity: FakeActivityGoals(prefs),
);

void main() {
  final now = DateTime(2026, 10, 22);

  group('StartingGoals', () {
    test('water follows body weight, rounded to a glass', () {
      final goals = StartingGoals.from(
        const OnboardingData(weight: '78', weightUnit: 'kg'),
        now: now,
      );
      // 78 kg x 35 ml = 2,730 ml -> 2,750 ml.
      expect(goals.waterMl, 2750);
    });

    test('water stays within 1.5-4 L and works in pounds', () {
      StartingGoals of(String w, String unit) => StartingGoals.from(
        OnboardingData(weight: w, weightUnit: unit),
        now: now,
      );
      expect(of('35', 'kg').waterMl, 1500);
      expect(of('180', 'kg').waterMl, 4000);
      expect(of('154', 'lb').waterMl, 2500); // ~70 kg
    });

    test('skipped answers keep the usual defaults', () {
      final goals = StartingGoals.from(const OnboardingData(), now: now);
      expect(goals.waterMl, StartingGoals.defaultWaterMl);
      expect(goals.dailySteps, 8000);
      expect(goals.weeklyWorkouts, 3);
      expect(goals.sleepMinutes, 480);
    });

    test('steps and workouts follow the activity level', () {
      StartingGoals of(String activity) =>
          StartingGoals.from(OnboardingData(activity: activity), now: now);
      expect(of('Mostly resting').dailySteps, 6000);
      expect(of('Mostly resting').weeklyWorkouts, 2);
      expect(of('Very active').dailySteps, 11000);
      expect(of('Very active').weeklyWorkouts, 5);
    });

    test('teens get nine hours of sleep', () {
      final teen = StartingGoals.from(
        const OnboardingData(dob: '01012011'),
        now: now,
      );
      expect(teen.sleepMinutes, 540);
    });
  });

  group('StartingGoalsWriter', () {
    const goals = StartingGoals(
      waterMl: 2750,
      dailySteps: 6000,
      weeklyWorkouts: 2,
      sleepMinutes: 540,
    );

    test('a new user gets the goals and no screen time limit', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await goalsWriter(prefs).save(goals);

      expect(WaterIntakeService(IsarService(), prefs).getDailyGoal(), 2750);
      expect(SleepService(IsarService(), prefs).getGoalMinutes(), 540);
      expect(ScreenTimeService(prefs).getDailyLimitMinutes(), isNull);
      final activity = {
        for (final g in FakeActivityGoals(prefs).getGoals()) g.id: g.target,
      };
      expect(activity, {'steps_daily': 6000, 'workouts_weekly': 2});
    });

    test('goals already saved (by hand or a backup) are kept', () async {
      SharedPreferences.setMockInitialValues({
        'daily_water_goal': 3000,
        'daily_sleep_goal_min': 420,
        'daily_screen_time_limit_min': 90,
        'activity_goals_v1': '[{"m":"distance","p":"daily","t":5}]',
      });
      final prefs = await SharedPreferences.getInstance();
      await goalsWriter(prefs).save(goals);

      expect(WaterIntakeService(IsarService(), prefs).getDailyGoal(), 3000);
      expect(SleepService(IsarService(), prefs).getGoalMinutes(), 420);
      expect(ScreenTimeService(prefs).getDailyLimitMinutes(), 90);
      expect(FakeActivityGoals(prefs).getGoals().map((g) => g.id), [
        'distance_daily',
      ]);
    });
  });

  test('installs that never saved a limit keep the 4 h default', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(
      ScreenTimeService(prefs).getDailyLimitMinutes(),
      ScreenTimeService.defaultLimitMinutes,
    );
  });
}
