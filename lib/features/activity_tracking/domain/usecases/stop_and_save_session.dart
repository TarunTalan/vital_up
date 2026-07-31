import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';

class StopAndSaveSession {
  final ActivityRepository repository;

  StopAndSaveSession(this.repository);

  Future<void> call(ActivitySession session) {
    return repository.saveSession(session);
  }
}
