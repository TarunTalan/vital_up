import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/delete_activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/save_session_annotation.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_state.dart';

class ActivityHistoryBloc extends Bloc<ActivityHistoryEvent, ActivityHistoryState> {
  final GetActivityHistory getActivityHistory;
  final SaveSessionAnnotation saveSessionAnnotation;
  final DeleteActivitySession deleteActivitySession;

  ActivityHistoryBloc({
    required this.getActivityHistory,
    required this.saveSessionAnnotation,
    required this.deleteActivitySession,
  }) : super(const ActivityHistoryLoading()) {
    on<LoadActivityHistory>(_onLoad);
    on<FilterByActivityType>(_onFilterByActivityType);
    on<SearchHistory>(_onSearch);
    on<UpdateSessionAnnotation>(_onUpdateAnnotation);
    on<DeleteSessionFromHistory>(_onDelete);
  }

  Future<void> _onLoad(
      LoadActivityHistory event,
      Emitter<ActivityHistoryState> emit,
      ) async {
    emit(const ActivityHistoryLoading());
    try {
      final entries = await getActivityHistory();
      emit(ActivityHistoryLoaded(
        allEntries: entries,
        visibleEntries: entries,
      ));
    } catch (e) {
      emit(ActivityHistoryError('Could not load activity history: $e'));
    }
  }

  void _onFilterByActivityType(
      FilterByActivityType event,
      Emitter<ActivityHistoryState> emit,
      ) {
    final s = state;
    if (s is! ActivityHistoryLoaded) return;

    final updated = s.copyWith(
      activityTypeFilter: event.activityType,
      clearActivityTypeFilter: event.activityType == null,
    );
    emit(updated.copyWith(visibleEntries: _applyFilters(updated)));
  }

  void _onSearch(SearchHistory event, Emitter<ActivityHistoryState> emit) {
    final s = state;
    if (s is! ActivityHistoryLoaded) return;

    final updated = s.copyWith(searchQuery: event.query);
    emit(updated.copyWith(visibleEntries: _applyFilters(updated)));
  }

  List<HistoryEntry> _applyFilters(ActivityHistoryLoaded s) {
    final query = s.searchQuery.trim().toLowerCase();

    return s.allEntries.where((entry) {
      final matchesType = s.activityTypeFilter == null ||
          entry.session.activityType == s.activityTypeFilter;

      if (!matchesType) return false;
      if (query.isEmpty) return true;

      final tag = entry.annotation?.tag?.toLowerCase() ?? '';
      final note = entry.annotation?.note?.toLowerCase() ?? '';
      return tag.contains(query) || note.contains(query);
    }).toList();
  }

  Future<void> _onUpdateAnnotation(
      UpdateSessionAnnotation event,
      Emitter<ActivityHistoryState> emit,
      ) async {
    final s = state;
    if (s is! ActivityHistoryLoaded) return;

    await saveSessionAnnotation(
      sessionId: event.sessionId,
      tag: event.tag,
      note: event.note,
    );

    final newAnnotation = SessionAnnotation(
      sessionId: event.sessionId,
      tag: event.tag,
      note: event.note,
      updatedAt: DateTime.now(),
    );

    final updatedAll = s.allEntries.map((entry) {
      if (entry.session.id != event.sessionId) return entry;
      return HistoryEntry(session: entry.session, annotation: newAnnotation);
    }).toList();

    final updated = s.copyWith(allEntries: updatedAll);
    emit(updated.copyWith(visibleEntries: _applyFilters(updated)));
  }

  Future<void> _onDelete(
      DeleteSessionFromHistory event,
      Emitter<ActivityHistoryState> emit,
      ) async {
    final s = state;
    if (s is! ActivityHistoryLoaded) return;

    await deleteActivitySession(event.sessionId);

    final updatedAll =
    s.allEntries.where((e) => e.session.id != event.sessionId).toList();
    final updated = s.copyWith(allEntries: updatedAll);
    emit(updated.copyWith(visibleEntries: _applyFilters(updated)));
  }
}