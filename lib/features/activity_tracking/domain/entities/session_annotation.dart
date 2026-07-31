import 'package:equatable/equatable.dart';

/// A user-editable annotation attached to a saved [ActivitySession].
///
/// Kept as a separate entity (rather than adding fields directly to
/// ActivitySession) so this feature doesn't require touching whatever
/// already persists sessions. A [ActivityHistoryRepository] implementation
/// just needs to store/retrieve these keyed by [sessionId].
class SessionAnnotation extends Equatable {
  final String sessionId;
  final String? tag;
  final String? note;
  final DateTime updatedAt;

  const SessionAnnotation({
    required this.sessionId,
    this.tag,
    this.note,
    required this.updatedAt,
  });

  SessionAnnotation copyWith({
    String? tag,
    String? note,
    DateTime? updatedAt,
  }) {
    return SessionAnnotation(
      sessionId: sessionId,
      tag: tag ?? this.tag,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [sessionId, tag, note, updatedAt];
}