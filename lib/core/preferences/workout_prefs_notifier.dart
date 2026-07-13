import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

const _kVoiceCoachKey = 'workout_voice_coach';
const _kCountdownKey = 'workout_countdown';
const _kTargetTypeKey = 'workout_target_type'; // 'none' | 'distance' | 'calories'
const _kTargetValueKey = 'workout_target_value';
const _kSelectedMetricsKey = 'workout_selected_metrics';

/// Type of workout goal the user has set.
enum WorkoutTargetType { none, distance, calories }

extension WorkoutTargetTypeLabel on WorkoutTargetType {
  String get label {
    return switch (this) {
      WorkoutTargetType.none => 'None',
      WorkoutTargetType.distance => 'Distance',
      WorkoutTargetType.calories => 'Calories',
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

/// Holds all workout preference toggles, active workout target, custom metrics layout, and music settings.
/// All values persist in [SharedPreferences].
class WorkoutPrefs {
  final bool voiceCoachEnabled;
  final int countdownDurationSeconds;
  final WorkoutTargetType targetType;
  final double targetValue; // km or kcal depending on targetType
  final List<StatMetric> selectedMetrics;
  final String backgroundAudioTrack; // 'None', 'Story: It\'s Possible', 'Lo-Fi Jogging Beats', 'Synthwave Cardio Energy'
  final String backgroundAudioQueueType; // 'curated', 'local', 'favorite'
  final ActivityType defaultActivityType;
  final String preferredPlayerPackage; // 'builtIn' or package name

  const WorkoutPrefs({
    this.voiceCoachEnabled = true,
    this.countdownDurationSeconds = 3,
    this.targetType = WorkoutTargetType.none,
    this.targetValue = 0.0,
    this.selectedMetrics = const [
      StatMetric.distance,
      StatMetric.calories,
      StatMetric.avgPace,
    ],
    this.backgroundAudioTrack = 'None',
    this.backgroundAudioQueueType = 'stories',
    this.defaultActivityType = ActivityType.walk,
    this.preferredPlayerPackage = 'builtIn',
  });

  WorkoutPrefs copyWith({
    bool? voiceCoachEnabled,
    int? countdownDurationSeconds,
    WorkoutTargetType? targetType,
    double? targetValue,
    List<StatMetric>? selectedMetrics,
    String? backgroundAudioTrack,
    String? backgroundAudioQueueType,
    ActivityType? defaultActivityType,
    String? preferredPlayerPackage,
  }) {
    return WorkoutPrefs(
      voiceCoachEnabled: voiceCoachEnabled ?? this.voiceCoachEnabled,
      countdownDurationSeconds: countdownDurationSeconds ?? this.countdownDurationSeconds,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      selectedMetrics: selectedMetrics ?? this.selectedMetrics,
      backgroundAudioTrack: backgroundAudioTrack ?? this.backgroundAudioTrack,
      backgroundAudioQueueType: backgroundAudioQueueType ?? this.backgroundAudioQueueType,
      defaultActivityType: defaultActivityType ?? this.defaultActivityType,
      preferredPlayerPackage: preferredPlayerPackage ?? this.preferredPlayerPackage,
    );
  }
}

/// A [ValueNotifier] that loads / saves [WorkoutPrefs] in SharedPreferences.
class WorkoutPrefsNotifier extends ValueNotifier<WorkoutPrefs> {
  WorkoutPrefsNotifier() : super(const WorkoutPrefs());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final targetTypeName =
        prefs.getString(_kTargetTypeKey) ?? WorkoutTargetType.none.name;
    final targetType = WorkoutTargetType.values.firstWhere(
      (e) => e.name == targetTypeName,
      orElse: () => WorkoutTargetType.none,
    );

    final savedMetrics = prefs.getStringList(_kSelectedMetricsKey);
    List<StatMetric> metrics = const [
      StatMetric.distance,
      StatMetric.calories,
      StatMetric.avgPace,
    ];
    if (savedMetrics != null) {
      metrics = savedMetrics
          .map((m) => StatMetric.values.firstWhere((e) => e.name == m, orElse: () => StatMetric.distance))
          .toList();
    }

    final defaultActivityTypeName =
        prefs.getString('workout_default_activity_type') ?? ActivityType.walk.name;
    final defaultActivityType = ActivityType.values.firstWhere(
      (e) => e.name == defaultActivityTypeName,
      orElse: () => ActivityType.walk,
    );

    final int defaultCountdown;
    if (prefs.containsKey(_kCountdownKey)) {
      defaultCountdown = (prefs.getBool(_kCountdownKey) ?? true) ? 3 : 0;
    } else {
      defaultCountdown = 3;
    }
    final countdownDuration = prefs.getInt('workout_countdown_duration') ?? defaultCountdown;

    value = WorkoutPrefs(
      voiceCoachEnabled: prefs.getBool(_kVoiceCoachKey) ?? true,
      countdownDurationSeconds: countdownDuration,
      targetType: targetType,
      targetValue: prefs.getDouble(_kTargetValueKey) ?? 0.0,
      selectedMetrics: metrics,
      backgroundAudioTrack: 'None',
      backgroundAudioQueueType: (prefs.getString('workout_audio_queue_type') == 'curated')
          ? 'stories'
          : (prefs.getString('workout_audio_queue_type') ?? 'stories'),
      defaultActivityType: defaultActivityType,
      preferredPlayerPackage: prefs.getString('workout_preferred_player_package') ?? 'builtIn',
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
        targetType: WorkoutTargetType.none, targetValue: 0.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTargetTypeKey, WorkoutTargetType.none.name);
    await prefs.setDouble(_kTargetValueKey, 0.0);
  }

  Future<void> setSelectedMetrics(List<StatMetric> metrics) async {
    value = value.copyWith(selectedMetrics: metrics);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedMetricsKey, metrics.map((e) => e.name).toList());
  }

  Future<void> setBackgroundAudioTrack(String track, {String? queueType}) async {
    final resolvedQueueType = queueType ?? (track.startsWith('Local:') ? 'local' : 'stories');
    value = value.copyWith(
      backgroundAudioTrack: track,
      backgroundAudioQueueType: resolvedQueueType,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workout_audio_track', track);
    await prefs.setString('workout_audio_queue_type', resolvedQueueType);
  }

  Future<void> setDefaultActivityType(ActivityType type) async {
    value = value.copyWith(defaultActivityType: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workout_default_activity_type', type.name);
  }

  Future<void> setPreferredPlayerPackage(String package) async {
    value = value.copyWith(preferredPlayerPackage: package);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workout_preferred_player_package', package);
  }
}
