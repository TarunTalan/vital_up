import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';

class StopAndSaveSession {
  final ActivityRepository repository;

  StopAndSaveSession(this.repository);

  Future<void> call(ActivitySession session) {
    return repository.saveSession(session);
  }

  /// Removes a session (and any checkpoint of it) that isn't worth keeping.
  Future<void> discard(String sessionId) {
    return repository.deleteSession(sessionId);
  }

  /// A session this short with nothing recorded is an accidental start:
  /// keeping it would clutter history and count as a logged workout.
  static const Duration minKeptDuration = Duration(seconds: 10);

  static bool isTooShortToKeep(ActivitySession session) =>
      session.totalDurationSeconds < minKeptDuration.inSeconds &&
      session.totalDistanceMeters < 1 &&
      session.steps == 0;
}
