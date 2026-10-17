import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';

abstract class ActivityRepository {
  Future<void> saveSession(ActivitySession session);
  /// Saved sessions, newest first. [since] limits them to those started
  /// at or after it; without [withRoutes] the GPS points are skipped (much
  /// cheaper when only totals are needed).
  Future<List<ActivitySession>> getSessions({
    DateTime? since,
    bool withRoutes = true,
  });
  Future<ActivitySession?> getSessionById(String id);
  Future<void> deleteSession(String id);

  /// Closes sessions left open by an app kill or crash mid-workout, keeping
  /// everything recorded up to their last checkpoint. Call at startup only.
  /// [keepOpenId] is a recent workout left open so the user can resume it.
  Future<void> finalizeInterruptedSessions({String? keepOpenId});
}
