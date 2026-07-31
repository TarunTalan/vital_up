import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';

/// A saved session paired with its optional tag/note annotation.
class HistoryEntry {
  final ActivitySession session;
  final SessionAnnotation? annotation;

  const HistoryEntry({required this.session, this.annotation});
}

/// Fetches every saved session along with its annotation, most recent first.
class GetActivityHistory {
  final ActivityHistoryRepository repository;

  GetActivityHistory(this.repository);

  Future<List<HistoryEntry>> call() async {
    final sessions = await repository.getSessions();
    final annotations = await repository.getAllAnnotations();

    final entries = sessions
        .map((session) => HistoryEntry(
      session: session,
      annotation: annotations[session.id],
    ))
        .toList();

    entries.sort((a, b) => b.session.startTime.compareTo(a.session.startTime));
    return entries;
  }
}