import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';

/// Provides access to previously completed activity sessions and any
/// user-added annotations (tag/note) for them.
///
/// NOTE: This project already has a data layer that persists sessions
/// (used by StopAndSaveSession). Wire this interface's implementation to
/// that same data source so history reads the sessions that were actually
/// saved, rather than a separate store.
abstract class ActivityHistoryRepository {
  /// Returns all saved sessions, most recent first.
  Future<List<ActivitySession>> getSessions();

  /// Returns the annotation (tag/note) for a session, if one was set.
  Future<SessionAnnotation?> getAnnotation(String sessionId);

  /// Returns annotations for every session in one call, keyed by session id.
  /// Useful so the history list doesn't need one lookup per row.
  Future<Map<String, SessionAnnotation>> getAllAnnotations();

  /// Creates or updates the tag/note for a session.
  Future<void> saveAnnotation(SessionAnnotation annotation);

  /// Deletes a saved session (and its annotation, if any).
  Future<void> deleteSession(String sessionId);
}