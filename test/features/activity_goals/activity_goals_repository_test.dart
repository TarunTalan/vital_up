import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_goals/data/datasources/activity_goals_local_datasource.dart';
import 'package:vital_up/features/activity_goals/data/repositories/activity_goals_repository_impl.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/vita/data/services/health_vitals_service.dart';

class _FakeHistory implements ActivityHistoryRepository {
  final List<ActivitySession> sessions;
  _FakeHistory(this.sessions);

  @override
  Future<List<ActivitySession>> getSessions() async => sessions;
  @override
  Future<Map<String, SessionAnnotation>> getAllAnnotations() async => {};
  @override
  Future<SessionAnnotation?> getAnnotation(String sessionId) async => null;
  @override
  Future<void> saveAnnotation(SessionAnnotation annotation) async {}
  @override
  Future<void> deleteSession(String sessionId) async {}
}

ActivitySession _walk(DateTime start, {double meters = 2500, int steps = 3000}) =>
    ActivitySession(
      id: start.toIso8601String(),
      activityType: ActivityType.walk,
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
      totalDistanceMeters: meters,
      totalDurationSeconds: 1800,
      avgPaceSecondsPerKm: 720,
      calories: 150,
      steps: steps,
      stepCountReliable: true,
      points: const [],
    );

Future<ActivityGoalsRepositoryImpl> _repo(List<ActivitySession> sessions) async {
  final prefs = await SharedPreferences.getInstance();
  return ActivityGoalsRepositoryImpl(
    local: ActivityGoalsLocalDataSource(prefs),
    history: GetActivityHistory(_FakeHistory(sessions)),
    // Not Android/iOS in tests → no health store, steps come from sessions.
    health: HealthVitalsService(prefs),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads progress with the default goals (nothing saved yet)', () async {
    final now = DateTime.now();
    final repo = await _repo([_walk(now)]);

    final snapshot = await repo.getProgress(TrendRange.week);

    expect(snapshot.goals.map((g) => g.goal.id), ['steps_daily', 'workouts_weekly']);
    final steps = snapshot.goals.first;
    expect(steps.current, 3000);
    expect(steps.series.points, hasLength(7));
    expect(snapshot.goals.last.current, 1);
    expect(snapshot.stepsFromHealth, isFalse);
  });

  test('save, replace and delete goals', () async {
    final repo = await _repo(const []);
    const distance = ActivityGoal(
      metric: GoalMetric.distance,
      period: GoalPeriod.weekly,
      target: 10,
    );
    await repo.saveGoal(distance);
    await repo.saveGoal(distance.copyWith(target: 20));
    expect(repo.getGoals().where((g) => g.id == distance.id).single.target, 20);

    await repo.deleteGoal(distance);
    expect(repo.getGoals().any((g) => g.id == distance.id), isFalse);
  });

  test('goal targets stay within sensible bounds', () {
    const m = GoalMetric.steps;
    expect(m.clampTarget(GoalPeriod.daily, -10), m.step);
    expect(m.clampTarget(GoalPeriod.daily, 1e9), m.maxDaily);
    expect(m.clampTarget(GoalPeriod.weekly, 1e9), m.maxDaily * 7);
    expect(m.clampTarget(GoalPeriod.daily, double.nan), m.daily);

    final stored = ActivityGoal.fromJson({'m': 'steps', 'p': 'daily', 't': 5e7});
    expect(stored!.target, m.maxDaily);
    expect(ActivityGoal.fromJson({'m': 'steps', 'p': 'daily', 't': 0}), isNull);
  });
}
