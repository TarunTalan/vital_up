import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

class ActivityGoalsState extends Equatable {
  final bool loading;
  final TrendRange range;
  final ActivityGoalsSnapshot? snapshot;

  /// Last load failed or timed out (any earlier [snapshot] is kept).
  final bool failed;

  /// Goal whose chart is shown on the goals page.
  final String? selectedId;

  const ActivityGoalsState({
    this.loading = true,
    this.range = TrendRange.week,
    this.snapshot,
    this.selectedId,
    this.failed = false,
  });

  List<GoalProgress> get goals => snapshot?.goals ?? const [];

  GoalProgress? get selected =>
      goals.where((g) => g.goal.id == selectedId).firstOrNull ??
      goals.firstOrNull;

  ActivityGoalsState copyWith({
    bool? loading,
    TrendRange? range,
    ActivityGoalsSnapshot? snapshot,
    String? selectedId,
    bool? failed,
  }) =>
      ActivityGoalsState(
        loading: loading ?? this.loading,
        range: range ?? this.range,
        snapshot: snapshot ?? this.snapshot,
        selectedId: selectedId ?? this.selectedId,
        failed: failed ?? this.failed,
      );

  @override
  List<Object?> get props => [loading, range, snapshot, selectedId, failed];
}

class ActivityGoalsCubit extends Cubit<ActivityGoalsState> {
  final ActivityGoalsRepository _repository;

  ActivityGoalsCubit(this._repository) : super(const ActivityGoalsState());

  Future<void> load([TrendRange? range]) async {
    final r = range ?? state.range;
    emit(state.copyWith(loading: true, range: r, failed: false));
    try {
      final snapshot = await _repository.getProgress(r).withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(loading: false, snapshot: snapshot));
    } catch (e, stack) {
      debugPrint('Activity goals failed to load: $e');
      debugPrintStack(stackTrace: stack);
      if (isClosed) return;
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  void select(ActivityGoal goal) => emit(state.copyWith(selectedId: goal.id));

  /// Returns false when the goal couldn't be stored.
  Future<bool> save(ActivityGoal goal) async {
    try {
      await _repository.saveGoal(goal);
    } catch (e) {
      debugPrint('Saving activity goal failed: $e');
      return false;
    }
    if (isClosed) return true;
    emit(state.copyWith(selectedId: goal.id));
    await load();
    return true;
  }

  /// Returns false when the goal couldn't be removed.
  Future<bool> delete(ActivityGoal goal) async {
    try {
      await _repository.deleteGoal(goal);
    } catch (e) {
      debugPrint('Deleting activity goal failed: $e');
      return false;
    }
    if (isClosed) return true;
    await load();
    return true;
  }
}
