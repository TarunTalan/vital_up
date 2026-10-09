import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/stop_and_save_session.dart';

/// Persists the [WorkoutCheckpoint] of the workout being recorded.
class WorkoutCheckpointStore {
  /// Removed on sign out (`AccountService.clearLocalUserData`).
  static const String key = 'activity_in_progress_v1';

  final SharedPreferences prefs;

  WorkoutCheckpointStore(this.prefs);

  WorkoutCheckpoint? read() => WorkoutCheckpoint.decode(prefs.getString(key));

  Future<void> write(WorkoutCheckpoint checkpoint) =>
      prefs.setString(key, checkpoint.encode());

  Future<void> clear() => prefs.remove(key);
}

/// A workout left open by an app kill, with what was recorded of it.
typedef InterruptedWorkout = ({
  WorkoutCheckpoint checkpoint,
  ActivitySession session,
  InterruptedWorkoutAction action,
});

enum InterruptedWorkoutOutcome { saved, discarded, failed }

/// Finds and settles workouts the app was killed in the middle of.
///
/// - At startup a recent one is left open for the tracking screen to offer
///   (resume, save, discard); anything else open is closed and kept.
/// - An old one (see [WorkoutCheckpoint.maxResumeAge]) is saved as it was,
///   or dropped when too short to keep.
class WorkoutRecoveryService {
  final ActivityRepository repository;
  final WorkoutCheckpointStore store;
  final DateTime Function() _now;

  WorkoutRecoveryService({
    required this.repository,
    required this.store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Run once at startup, before any workout can be recording.
  Future<void> settleAtStartup() async {
    String? keepOpen;
    try {
      final pending = await this.pending();
      if (pending != null) {
        if (pending.action == InterruptedWorkoutAction.offerResume) {
          keepOpen = pending.checkpoint.sessionId;
        } else {
          await finish(pending);
        }
      }
    } catch (e) {
      debugPrint('Checking the interrupted workout failed: $e');
    }
    await repository.finalizeInterruptedSessions(keepOpenId: keepOpen);
  }

  /// The workout waiting to be resumed or saved, if any. A checkpoint whose
  /// session is gone or already finished is cleared.
  Future<InterruptedWorkout?> pending() async {
    final checkpoint = store.read();
    if (checkpoint == null) {
      // Unreadable or absent: make sure no corrupt value lingers.
      if (store.prefs.containsKey(WorkoutCheckpointStore.key)) {
        await store.clear();
      }
      return null;
    }
    final session = await repository.getSessionById(checkpoint.sessionId);
    if (session == null || session.endTime != null) {
      await store.clear();
      return null;
    }
    return (
      checkpoint: checkpoint,
      session: session,
      action: checkpoint.decide(_now()),
    );
  }

  /// Saves the workout as recorded up to its last checkpoint. One too short
  /// to keep is deleted instead, like a normal finish.
  Future<InterruptedWorkoutOutcome> finish(
    InterruptedWorkout workout, {
    String? targetType,
    double? targetValue,
    bool targetAchieved = false,
  }) async {
    final finished = workout.checkpoint.finishedSession(
      workout.session,
      targetType: targetType,
      targetValue: targetValue,
      targetAchieved: targetAchieved,
    );
    try {
      if (StopAndSaveSession.isTooShortToKeep(finished)) {
        await repository.deleteSession(finished.id);
        await store.clear();
        return InterruptedWorkoutOutcome.discarded;
      }
      await repository.saveSession(finished);
      await store.clear();
      return InterruptedWorkoutOutcome.saved;
    } catch (e) {
      debugPrint('Saving the interrupted workout failed: $e');
      return InterruptedWorkoutOutcome.failed;
    }
  }

  /// Deletes the workout and everything recorded of it.
  Future<bool> discard(InterruptedWorkout workout) async {
    try {
      await repository.deleteSession(workout.session.id);
      await store.clear();
      return true;
    } catch (e) {
      debugPrint('Discarding the interrupted workout failed: $e');
      return false;
    }
  }
}
