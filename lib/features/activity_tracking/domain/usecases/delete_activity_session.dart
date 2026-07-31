import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';

/// Deletes a saved session from history.
class DeleteActivitySession {
  final ActivityHistoryRepository repository;

  DeleteActivitySession(this.repository);

  Future<void> call(String sessionId) {
    return repository.deleteSession(sessionId);
  }
}