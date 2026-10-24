import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

const _kVoiceCoachKey = 'workout_voice_coach';
const _kCountdownKey = 'workout_countdown';
const _kTargetTypeKey =
    'workout_target_type'; // 'none' | 'distance' | 'calories'
const _kTargetValueKey = 'workout_target_value';
const _kSelectedMetricsKey = 'workout_selected_metrics';
// The workout timer's own target: [WorkoutTargetType.duration] (minutes) or
// calories. Kept apart so GPS targets are untouched.
const _kTimerTargetTypeKey = 'workout_timer_target_type';
const _kTimerTargetValueKey = 'workout_timer_target_value';

/// Settings that were replaced: the activity now follows the activity
/// goals, and their daily distance / calories goal is the workout target.
/// Removed from prefs on the next load.
const _kRetiredKeys = [
  'workout_daily_target_enabled',
  'workout_daily_target_type',
  'workout_daily_target_value',
  'workout_default_activity_type',
];

/// Type of workout goal the user has set. GPS workouts use distance or
/// calories; workouts without a route use duration (minutes) or calories.
enum WorkoutTargetType { none, distance, calories, duration }

extension WorkoutTargetTypeLabel on WorkoutTargetType {
  String get label {
    return switch (this) {
      WorkoutTargetType.none => 'None',
      WorkoutTargetType.distance => 'Distance',
      WorkoutTargetType.calories => 'Calories',
      WorkoutTargetType.duration => 'Time',
    };
  }
}

// Removed AudioPlayerType enum

/// Metrics that can be displayed on the tracking screen.
enum StatMetric {
  distance,
  calories,
  avgPace,
  currentSpeed,
  steps,
  elevationGain,
  activityType;

  String get label {
    return switch (this) {
      StatMetric.distance => 'Distance',
      StatMetric.calories => 'Calories',
      StatMetric.avgPace => 'Avg. Pace',
      StatMetric.currentSpeed => 'Current Speed',
      StatMetric.steps => 'Steps',
      StatMetric.elevationGain => 'Elevation Gain',
      StatMetric.activityType => 'Activity Type',
    };
  }

  String get code {
    return name;
  }
}

/// The live stats a workout shows until the user picks their own layout:
/// steps on foot, pace on a run, speed on a ride.
List<StatMetric> defaultStatsFor(ActivityType type) => [
  StatMetric.distance,
  switch (type) {
    ActivityType.run => StatMetric.avgPace,
    ActivityType.cycle => StatMetric.currentSpeed,
    _ => StatMetric.steps,
  },
  StatMetric.calories,
];

/// Holds all workout preference toggles, active workout target, custom metrics layout, and music settings.
/// All values persist in [SharedPreferences].
class WorkoutPrefs {
  final bool voiceCoachEnabled;
  final int countdownDurationSeconds;
  final WorkoutTargetType targetType;
  final double targetValue; // km or kcal depending on targetType
  /// The user's own layout; empty until they save one, and the workout
  /// shows [defaultStatsFor] its type instead.
  final List<StatMetric> selectedMetrics;
  final String
  backgroundAudioTrack; // 'None', 'Story: It\'s Possible', 'Lo-Fi Jogging Beats', 'Synthwave Cardio Energy'
  final String backgroundAudioQueueType; // 'curated', 'local', 'favorite'
  final String preferredPlayerPackage; // 'builtIn' or package name

  /// The workout timer's target (duration in minutes, or kcal).
  final WorkoutTargetType timerTargetType;
  final double timerTargetValue;

  const WorkoutPrefs({
    this.voiceCoachEnabled = true,
    this.countdownDurationSeconds = 3,
    this.targetType = WorkoutTargetType.none,
    this.targetValue = 0.0,
    this.selectedMetrics = const [],
    this.backgroundAudioTrack = 'None',
    this.backgroundAudioQueueType = 'stories',
    this.preferredPlayerPackage = 'builtIn',
    this.timerTargetType = WorkoutTargetType.none,
    this.timerTargetValue = 0.0,
  });

  WorkoutPrefs copyWith({
    bool? voiceCoachEnabled,
    int? countdownDurationSeconds,
    WorkoutTargetType? targetType,
    double? targetValue,
    List<StatMetric>? selectedMetrics,
    String? backgroundAudioTrack,
    String? backgroundAudioQueueType,
    String? preferredPlayerPackage,
    WorkoutTargetType? timerTargetType,
    double? timerTargetValue,
  }) {
    return WorkoutPrefs(
      voiceCoachEnabled: voiceCoachEnabled ?? this.voiceCoachEnabled,
      countdownDurationSeconds:
          countdownDurationSeconds ?? this.countdownDurationSeconds,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      selectedMetrics: selectedMetrics ?? this.selectedMetrics,
      backgroundAudioTrack: backgroundAudioTrack ?? this.backgroundAudioTrack,
      backgroundAudioQueueType:
          backgroundAudioQueueType ?? this.backgroundAudioQueueType,
      preferredPlayerPackage:
          preferredPlayerPackage ?? this.preferredPlayerPackage,
      timerTargetType: timerTargetType ?? this.timerTargetType,
      timerTargetValue: timerTargetValue ?? this.timerTargetValue,
    );
  }
}

/// A [ValueNotifier] that loads / saves [WorkoutPrefs] in SharedPreferences.
class WorkoutPrefsNotifier extends ValueNotifier<WorkoutPrefs> {
  WorkoutPrefsNotifier() : super(const WorkoutPrefs());

  /// The saved settings once, for code without a screen (the timer's
  /// voice coach).
  static Future<WorkoutPrefs> read() async {
    final notifier = WorkoutPrefsNotifier();
    try {
      await notifier.load();
      return notifier.value;
    } finally {
      notifier.dispose();
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final targetTypeName =
        prefs.getString(_kTargetTypeKey) ?? WorkoutTargetType.none.name;
    final targetType = WorkoutTargetType.values.firstWhere(
      (e) => e.name == targetTypeName,
      orElse: () => WorkoutTargetType.none,
    );

    final savedMetrics = prefs.getStringList(_kSelectedMetricsKey);
    List<StatMetric> metrics = const [];
    if (savedMetrics != null) {
      metrics = savedMetrics
          .map(
            (m) => StatMetric.values.firstWhere(
              (e) => e.name == m,
              orElse: () => StatMetric.distance,
            ),
          )
          .toList();
    }

    for (final key in _kRetiredKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }

    final int defaultCountdown;
    if (prefs.containsKey(_kCountdownKey)) {
      defaultCountdown = (prefs.getBool(_kCountdownKey) ?? true) ? 3 : 0;
    } else {
      defaultCountdown = 3;
    }
    final countdownDuration =
        prefs.getInt('workout_countdown_duration') ?? defaultCountdown;

    value = WorkoutPrefs(
      voiceCoachEnabled: prefs.getBool(_kVoiceCoachKey) ?? true,
      countdownDurationSeconds: countdownDuration,
      targetType: targetType,
      targetValue: prefs.getDouble(_kTargetValueKey) ?? 0.0,
      selectedMetrics: metrics,
      backgroundAudioTrack: 'None',
      backgroundAudioQueueType:
          (prefs.getString('workout_audio_queue_type') == 'curated')
          ? 'stories'
          : (prefs.getString('workout_audio_queue_type') ?? 'stories'),
      preferredPlayerPackage:
          prefs.getString('workout_preferred_player_package') ?? 'builtIn',
      timerTargetType: WorkoutTargetType.values.firstWhere(
        (e) =>
            e.name == prefs.getString(_kTimerTargetTypeKey) &&
            (e == WorkoutTargetType.duration ||
                e == WorkoutTargetType.calories),
        orElse: () => WorkoutTargetType.none,
      ),
      timerTargetValue: prefs.getDouble(_kTimerTargetValueKey) ?? 0.0,
    );
  }

  Future<void> setVoiceCoach(bool enabled) async {
    value = value.copyWith(voiceCoachEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceCoachKey, enabled);
  }

  Future<void> setCountdownDuration(int durationSeconds) async {
    value = value.copyWith(countdownDurationSeconds: durationSeconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workout_countdown_duration', durationSeconds);
    await prefs.setBool(_kCountdownKey, durationSeconds > 0);
  }

  Future<void> setTarget(WorkoutTargetType type, double targetValue) async {
    value = value.copyWith(targetType: type, targetValue: targetValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTargetTypeKey, type.name);
    await prefs.setDouble(_kTargetValueKey, targetValue);
  }

  Future<void> clearTarget() async {
    value = value.copyWith(
      targetType: WorkoutTargetType.none,
      targetValue: 0.0,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTargetTypeKey, WorkoutTargetType.none.name);
    await prefs.setDouble(_kTargetValueKey, 0.0);
  }

  Future<void> setSelectedMetrics(List<StatMetric> metrics) async {
    value = value.copyWith(selectedMetrics: metrics);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSelectedMetricsKey,
      metrics.map((e) => e.name).toList(),
    );
  }

  Future<void> setBackgroundAudioTrack(
    String track, {
    String? queueType,
  }) async {
    final resolvedQueueType =
        queueType ?? (track.startsWith('Local:') ? 'local' : 'stories');
    value = value.copyWith(
      backgroundAudioTrack: track,
      backgroundAudioQueueType: resolvedQueueType,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workout_audio_track', track);
    await prefs.setString('workout_audio_queue_type', resolvedQueueType);
  }

  Future<void> setPreferredPlayerPackage(String package) async {
    value = value.copyWith(preferredPlayerPackage: package);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workout_preferred_player_package', package);
  }

  /// The workout timer's target: [WorkoutTargetType.duration] (minutes) or
  /// calories.
  Future<void> setTimerTarget(
    WorkoutTargetType type,
    double targetValue,
  ) async {
    value = value.copyWith(
      timerTargetType: type,
      timerTargetValue: targetValue,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTimerTargetTypeKey, type.name);
    await prefs.setDouble(_kTimerTargetValueKey, targetValue);
  }

  /// Clears the workout timer's target (after a workout is saved or
  /// discarded, or from settings).
  Future<void> clearTimerTarget() async {
    value = value.copyWith(
      timerTargetType: WorkoutTargetType.none,
      timerTargetValue: 0.0,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTimerTargetTypeKey);
    await prefs.remove(_kTimerTargetValueKey);
  }

  /// Clears the per-session target. Call after a session is saved.
  Future<void> clearSessionTarget() async {
    await clearTarget();
  }
}
