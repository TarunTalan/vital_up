import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';

/// Saves a workout without a route (timed in the app or logged after the
/// fact). Goes through the same repository as GPS workouts, so it syncs,
/// counts toward goals, challenges and badges, and shows in history.
class LogWorkout {
  final ActivityRepository repository;

  /// The user's weight for calories; null when unknown.
  final Future<double?> Function() weightKg;
  final DateTime Function() _now;

  LogWorkout({
    required this.repository,
    required this.weightKg,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Throws [ArgumentError] with the user message when the entry breaks
  /// [workoutEntryError] (callers check first; this guards the data).
  Future<ActivitySession> call({
    required ActivityType type,
    required DateTime start,
    required Duration length,
    required WorkoutIntensity intensity,
    String? targetType,
    double? targetValue,
    bool targetAchieved = false,
  }) async {
    final error = workoutEntryError(start, length, now: _now());
    if (error != null) throw ArgumentError(error);

    double? weight;
    try {
      weight = await weightKg();
    } catch (e) {
      // Calories fall back to an average weight; the workout still saves.
      debugPrint('Reading weight for workout calories failed: $e');
    }
    final session = buildWorkoutSession(
      id: const Uuid().v4(),
      type: type,
      start: start,
      length: Duration(seconds: length.inSeconds),
      intensity: intensity,
      weightKg: weight ?? WorkoutLogRules.fallbackWeightKg,
      targetType: targetType,
      targetValue: targetValue,
      targetAchieved: targetAchieved,
    );
    await repository.saveSession(session);
    return session;
  }
}
