import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

void main() {
  test('workouts on foot show steps until a layout is saved', () {
    for (final type in [
      ActivityType.walk,
      ActivityType.trekking,
      ActivityType.climbing,
    ]) {
      expect(defaultStatsFor(type), contains(StatMetric.steps));
    }
    expect(defaultStatsFor(ActivityType.run), contains(StatMetric.avgPace));
    expect(
      defaultStatsFor(ActivityType.cycle),
      contains(StatMetric.currentSpeed),
    );
  });

  test('a saved layout is kept; none saved means the defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = WorkoutPrefsNotifier();
    addTearDown(notifier.dispose);
    await notifier.load();
    expect(notifier.value.selectedMetrics, isEmpty);

    await notifier.setSelectedMetrics([StatMetric.distance]);
    final reloaded = WorkoutPrefsNotifier();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.value.selectedMetrics, [StatMetric.distance]);
  });
}
