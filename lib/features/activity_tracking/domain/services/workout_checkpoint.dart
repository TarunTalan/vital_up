import 'dart:convert';

import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';

/// What the app should offer for a workout left open by an app kill.
enum InterruptedWorkoutAction {
  /// Recent enough to carry on: offer resume, save or discard.
  offerResume,

  /// Too old to carry on as one workout: save it as it was (or drop it if
  /// it is too short to keep).
  saveOnly,
}

/// Small marker of the workout being recorded, written next to the Drift
/// checkpoint of the session (which holds the distance, duration, steps and
/// route). It carries what the session row doesn't: when it was last
/// written, the pause state, the climb and the weight used for calories.
///
/// Pure: no I/O, so encoding, staleness and restore math are unit-tested.
class WorkoutCheckpoint {
  /// Bump when the format changes; older payloads are ignored.
  static const int version = 1;

  /// A workout last seen longer ago than this is not resumed: carrying on
  /// would merge two outings into one. It is saved as it was instead.
  static const Duration maxResumeAge = Duration(hours: 12);

  /// Clock skew tolerated when the checkpoint seems to come from the future
  /// (the clock was changed after it was written).
  static const Duration _futureTolerance = Duration(minutes: 5);

  final String sessionId;

  /// Wall time of the last checkpoint: the last moment the workout is
  /// known to have been recording.
  final DateTime savedAt;

  /// Whether the workout was paused at that moment.
  final bool paused;

  final double elevationGainMeters;

  /// Weight used for calories, so a resumed workout keeps the same maths.
  final double weightKg;

  const WorkoutCheckpoint({
    required this.sessionId,
    required this.savedAt,
    required this.paused,
    this.elevationGainMeters = 0.0,
    this.weightKg = 70.0,
  });

  String encode() => jsonEncode({
        'v': version,
        'id': sessionId,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'paused': paused,
        'elevation': elevationGainMeters,
        'weightKg': weightKg,
      });

  /// Null for anything missing, malformed or from another format version,
  /// so a corrupt pref can never block the tracking screen.
  static WorkoutCheckpoint? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['v'] != version) return null;
      final id = json['id'];
      final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '');
      if (id is! String || id.isEmpty || savedAt == null) return null;
      return WorkoutCheckpoint(
        sessionId: id,
        savedAt: savedAt.toLocal(),
        paused: json['paused'] == true,
        elevationGainMeters: _finiteOr(json['elevation'], 0.0, min: 0),
        weightKg: _finiteOr(json['weightKg'], 70.0, min: 1),
      );
    } catch (_) {
      return null;
    }
  }

  static double _finiteOr(Object? value, double fallback, {required double min}) {
    if (value is! num) return fallback;
    final v = value.toDouble();
    return v.isFinite && v >= min ? v : fallback;
  }

  /// Resume only while the workout is recent. A checkpoint dated in the
  /// future beyond a small skew can't be trusted either way, so it is saved.
  InterruptedWorkoutAction decide(DateTime now) {
    final age = now.difference(savedAt);
    if (age.isNegative) {
      return -age <= _futureTolerance
          ? InterruptedWorkoutAction.offerResume
          : InterruptedWorkoutAction.saveOnly;
    }
    return age <= maxResumeAge
        ? InterruptedWorkoutAction.offerResume
        : InterruptedWorkoutAction.saveOnly;
  }

  /// Active time to carry on from. The time the app was dead is never
  /// counted: nothing was recorded then, and counting it would inflate
  /// the duration and wreck the pace.
  static Duration restoredElapsed(ActivitySession session) =>
      Duration(seconds: session.totalDurationSeconds.clamp(0, 1 << 31).toInt());

  /// End time for a workout saved after an interruption: the last moment it
  /// was known to be recording, but never earlier than start + active time
  /// (the checkpoint can be a little behind the session row, or the clock
  /// may have moved).
  DateTime finishedEndTime(ActivitySession session) {
    final earliest = session.startTime.add(restoredElapsed(session));
    return savedAt.isAfter(earliest) ? savedAt : earliest;
  }

  /// [session] closed with [finishedEndTime] and the given target result.
  ActivitySession finishedSession(
    ActivitySession session, {
    String? targetType,
    double? targetValue,
    bool targetAchieved = false,
  }) {
    return ActivitySession(
      id: session.id,
      activityType: session.activityType,
      startTime: session.startTime,
      endTime: finishedEndTime(session),
      totalDistanceMeters: session.totalDistanceMeters,
      totalDurationSeconds: session.totalDurationSeconds,
      avgPaceSecondsPerKm: session.avgPaceSecondsPerKm,
      calories: session.calories,
      steps: session.steps,
      stepCountReliable: session.stepCountReliable,
      points: session.points,
      targetType: targetType ?? session.targetType,
      targetValue: targetValue ?? session.targetValue,
      targetAchieved: targetType != null ? targetAchieved : session.targetAchieved,
    );
  }
}
