import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';

abstract class ActivityHistoryState extends Equatable {
  const ActivityHistoryState();

  @override
  List<Object?> get props => [];
}

class ActivityHistoryLoading extends ActivityHistoryState {
  const ActivityHistoryLoading();
}

class ActivityHistoryError extends ActivityHistoryState {
  final String message;

  const ActivityHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

class ActivityHistoryLoaded extends ActivityHistoryState {
  /// All entries as loaded from the repository, unfiltered.
  final List<HistoryEntry> allEntries;

  /// Entries after applying [activityTypeFilter] and [searchQuery].
  final List<HistoryEntry> visibleEntries;

  final ActivityType? activityTypeFilter;
  final String searchQuery;

  const ActivityHistoryLoaded({
    required this.allEntries,
    required this.visibleEntries,
    this.activityTypeFilter,
    this.searchQuery = '',
  });

  /// Aggregate totals across all (unfiltered) entries, handy for a summary
  /// header on the history page.
  int get totalSessions => allEntries.length;

  double get totalDistanceMeters =>
      allEntries.fold(0.0, (sum, e) => sum + e.session.totalDistanceMeters);

  int get totalDurationSeconds =>
      allEntries.fold(0, (sum, e) => sum + e.session.totalDurationSeconds);

  int get totalCalories =>
      allEntries.fold(0, (sum, e) => sum + e.session.calories);

  ActivityHistoryLoaded copyWith({
    List<HistoryEntry>? allEntries,
    List<HistoryEntry>? visibleEntries,
    ActivityType? activityTypeFilter,
    bool clearActivityTypeFilter = false,
    String? searchQuery,
  }) {
    return ActivityHistoryLoaded(
      allEntries: allEntries ?? this.allEntries,
      visibleEntries: visibleEntries ?? this.visibleEntries,
      activityTypeFilter: clearActivityTypeFilter
          ? null
          : (activityTypeFilter ?? this.activityTypeFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    allEntries,
    visibleEntries,
    activityTypeFilter,
    searchQuery,
  ];
}