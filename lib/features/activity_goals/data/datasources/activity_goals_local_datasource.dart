import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';

/// Activity goals stored on device as a JSON list.
class ActivityGoalsLocalDataSource {
  final SharedPreferences _prefs;

  static const _key = 'activity_goals_v1';

  /// Shown until the user sets their own goals.
  static const defaults = [
    ActivityGoal(metric: GoalMetric.steps, period: GoalPeriod.daily, target: 8000),
    ActivityGoal(metric: GoalMetric.workouts, period: GoalPeriod.weekly, target: 3),
  ];

  ActivityGoalsLocalDataSource(this._prefs);

  /// Always a fresh, modifiable list (never the const [defaults]).
  List<ActivityGoal> read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [...defaults];
    try {
      return [
        for (final item in (jsonDecode(raw) as List).whereType<Map<String, dynamic>>())
          ?ActivityGoal.fromJson(item),
      ];
    } catch (_) {
      return [...defaults];
    }
  }

  Future<void> write(List<ActivityGoal> goals) => _prefs.setString(
        _key,
        jsonEncode([for (final g in goals) g.toJson()]),
      );
}
