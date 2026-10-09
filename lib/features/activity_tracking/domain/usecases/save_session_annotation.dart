import 'package:vital_up/core/utils/input_rules.dart';
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
        // Notes are backed up to the server: never store raw input.
        tag: sanitizeOptional(tag, maxLength: SessionAnnotationLimits.tag),
        note: sanitizeOptional(
          note,
          maxLength: SessionAnnotationLimits.note,
          multiline: true,
        ),
        updatedAt: DateTime.now(),
      ),
    );
  }
}