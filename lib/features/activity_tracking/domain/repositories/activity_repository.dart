import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';

abstract class ActivityRepository {
  Future<void> saveSession(ActivitySession session);
  Future<List<ActivitySession>> getSessions();
  Future<ActivitySession?> getSessionById(String id);
  Future<void> deleteSession(String id);
}
