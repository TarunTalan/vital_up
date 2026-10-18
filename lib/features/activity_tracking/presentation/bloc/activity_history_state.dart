import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';

/// The two kinds of session the history list can be narrowed to.
enum ActivityGroup {
  /// GPS activities: walking, running, cycling, trekking, climbing.
  outdoor,

  /// Workouts without a route: gym, studio, pool, court.
  workouts;

  String get label => switch (this) {
    ActivityGroup.outdoor => 'Outdoor',
    ActivityGroup.workouts => 'Workouts',
  };

  bool contains(ActivityType type) =>
      type.isGpsBased == (this == ActivityGroup.outdoor);
}

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

  /// Entries after applying [groupFilter], [activityTypeFilter] and
  /// [searchQuery].
  final List<HistoryEntry> visibleEntries;

  /// At most one of [groupFilter] and [activityTypeFilter] is set.
  final ActivityGroup? groupFilter;
  final ActivityType? activityTypeFilter;
  final String searchQuery;

  /// Message for the last failed save or delete, shown once as a snackbar.
  /// [actionErrorId] changes with every failure so repeats still show.
  final String? actionError;
  final int actionErrorId;

  const ActivityHistoryLoaded({
    required this.allEntries,
    required this.visibleEntries,
    this.groupFilter,
    this.activityTypeFilter,
    this.searchQuery = '',
    this.actionError,
    this.actionErrorId = 0,
  });

  /// Aggregate totals across all (unfiltered) entries, handy for a summary
  /// header on the history page.
  int get totalSessions => allEntries.length;

  /// Types with at least one session, in menu order, for the type chips.
  List<ActivityType> get recordedTypes {
    final seen = {for (final e in allEntries) e.session.activityType};
    return ActivityType.values.where(seen.contains).toList();
  }

  double get totalDistanceMeters =>
      allEntries.fold(0.0, (sum, e) => sum + e.session.totalDistanceMeters);

  int get totalDurationSeconds =>
      allEntries.fold(0, (sum, e) => sum + e.session.totalDurationSeconds);

  int get totalCalories =>
      allEntries.fold(0, (sum, e) => sum + e.session.calories);

  ActivityHistoryLoaded copyWith({
    List<HistoryEntry>? allEntries,
    List<HistoryEntry>? visibleEntries,
    ActivityGroup? groupFilter,
    bool clearGroupFilter = false,
    ActivityType? activityTypeFilter,
    bool clearActivityTypeFilter = false,
    String? searchQuery,
    String? actionError,
  }) {
    return ActivityHistoryLoaded(
      allEntries: allEntries ?? this.allEntries,
      visibleEntries: visibleEntries ?? this.visibleEntries,
      groupFilter: clearGroupFilter ? null : (groupFilter ?? this.groupFilter),
      activityTypeFilter: clearActivityTypeFilter
          ? null
          : (activityTypeFilter ?? this.activityTypeFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      actionError: actionError ?? this.actionError,
      actionErrorId: actionError != null ? actionErrorId + 1 : actionErrorId,
    );
  }

  @override
  List<Object?> get props => [
    allEntries,
    visibleEntries,
    groupFilter,
    activityTypeFilter,
    searchQuery,
    actionError,
    actionErrorId,
  ];
}