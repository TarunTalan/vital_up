import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_state.dart';

abstract class ActivityHistoryEvent extends Equatable {
  const ActivityHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Loads (or reloads) the full session history.
class LoadActivityHistory extends ActivityHistoryEvent {}

/// Filters the visible list to outdoor activities or workouts. Pass null to
/// clear every filter. Replaces a type filter.
class FilterByActivityGroup extends ActivityHistoryEvent {
  final ActivityGroup? group;

  const FilterByActivityGroup(this.group);

  @override
  List<Object?> get props => [group];
}

/// Filters the visible list by activity type. Pass null to clear every
/// filter. Replaces a group filter.
class FilterByActivityType extends ActivityHistoryEvent {
  final ActivityType? activityType;

  const FilterByActivityType(this.activityType);

  @override
  List<Object?> get props => [activityType];
}

/// Filters the visible list by a free-text search over tag/note.
class SearchHistory extends ActivityHistoryEvent {
  final String query;

  const SearchHistory(this.query);

  @override
  List<Object?> get props => [query];
}

/// Saves or updates the tag/note for a session.
class UpdateSessionAnnotation extends ActivityHistoryEvent {
  final String sessionId;
  final String? tag;
  final String? note;

  const UpdateSessionAnnotation({
    required this.sessionId,
    this.tag,
    this.note,
  });

  @override
  List<Object?> get props => [sessionId, tag, note];
}

/// Removes a session from history.
class DeleteSessionFromHistory extends ActivityHistoryEvent {
  final String sessionId;

  const DeleteSessionFromHistory(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}