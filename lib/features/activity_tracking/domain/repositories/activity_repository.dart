import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';

abstract class ActivityRepository {
  Future<void> saveSession(ActivitySession session);
  /// Saved sessions, newest first. [since] limits them to those started
  /// at or after it. GPS points are only loaded with [withRoutes] (a route
  /// is thousands of points; almost every reader only needs totals).
  Future<List<ActivitySession>> getSessions({
    DateTime? since,
    bool withRoutes = false,
  });
  Future<ActivitySession?> getSessionById(String id);
  Future<void> deleteSession(String id);

  /// Closes sessions left open by an app kill or crash mid-workout, keeping
  /// everything recorded up to their last checkpoint. Call at startup only.
  /// [keepOpenId] is a recent workout left open so the user can resume it.
  Future<void> finalizeInterruptedSessions({String? keepOpenId});
}
