import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';

/// Creates or updates the tag/note attached to a saved session.
class SaveSessionAnnotation {
  final ActivityHistoryRepository repository;

  SaveSessionAnnotation(this.repository);

  Future<void> call({
    required String sessionId,
    String? tag,
    String? note,
  }) {
    return repository.saveAnnotation(
      SessionAnnotation(
        sessionId: sessionId,
        tag: tag,
        note: note,
        updatedAt: DateTime.now(),
      ),
    );
  }
}