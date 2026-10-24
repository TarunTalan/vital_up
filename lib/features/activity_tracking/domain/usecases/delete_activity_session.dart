import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';

/// Deletes a saved session from history.
class DeleteActivitySession {
  final ActivityHistoryRepository repository;

  /// Runs after a delete, e.g. to drop the resume point of a workout the
  /// app was closed during (else Home's bar would still offer it).
  final Future<void> Function(String sessionId)? afterDelete;

  DeleteActivitySession(this.repository, {this.afterDelete});

  Future<void> call(String sessionId) async {
    await repository.deleteSession(sessionId);
    await afterDelete?.call(sessionId);
  }
}
