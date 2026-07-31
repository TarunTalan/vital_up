import 'package:bloc/bloc.dart';
import '../../data/services/water_intake_service.dart';
import 'water_intake_state.dart';

class WaterIntakeCubit extends Cubit<WaterIntakeState> {
  final WaterIntakeService _service;
  String? _userId;

  WaterIntakeCubit(this._service) : super(WaterIntakeInitial());

  Future<void> loadData(String userId) async {
    _userId = userId;
    emit(WaterIntakeLoading());
    try {
      final goal = _service.getDailyGoal();
      final logs = await _service.getTodayLogs(userId);
      final currentIntake = logs.fold<int>(0, (sum, log) => sum + log.amountMl);
      
      emit(WaterIntakeLoaded(
        currentIntakeMl: currentIntake,
        dailyGoalMl: goal,
        todayLogs: logs,
      ));
    } catch (e) {
      emit(WaterIntakeError(e.toString()));
    }
  }

  Future<void> addWater(int amountMl) async {
    if (_userId == null) return;
    if (state is! WaterIntakeLoaded) return;

    final currentState = state as WaterIntakeLoaded;
    
    // Optimistic UI update
    final optimisticIntake = currentState.currentIntakeMl + amountMl;
    emit(WaterIntakeLoaded(
      currentIntakeMl: optimisticIntake,
      dailyGoalMl: currentState.dailyGoalMl,
      todayLogs: currentState.todayLogs, // Will update logs list once DB returns
    ));

    try {
      final newLog = await _service.addWaterLog(_userId!, amountMl);
      final updatedLogs = List.of(currentState.todayLogs)..add(newLog);
      
      emit(WaterIntakeLoaded(
        currentIntakeMl: optimisticIntake,
        dailyGoalMl: currentState.dailyGoalMl,
        todayLogs: updatedLogs,
      ));
    } catch (e) {
      // Rollback on failure
      emit(currentState);
      emit(WaterIntakeError('Failed to add water: $e'));
      emit(currentState); // Re-emit loaded state so UI recovers
    }
  }

  Future<void> undoLast() async {
    if (state is! WaterIntakeLoaded) return;
    final currentState = state as WaterIntakeLoaded;
    if (currentState.todayLogs.isEmpty) return;

    final lastLog = currentState.todayLogs.last;
    
    // Optimistic update
    final optimisticIntake = currentState.currentIntakeMl - lastLog.amountMl;
    final updatedLogs = List.of(currentState.todayLogs)..removeLast();
    
    emit(WaterIntakeLoaded(
      currentIntakeMl: optimisticIntake,
      dailyGoalMl: currentState.dailyGoalMl,
      todayLogs: updatedLogs,
    ));

    try {
      await _service.deleteWaterLog(lastLog.id);
    } catch (e) {
      // Rollback
      emit(currentState);
      emit(WaterIntakeError('Failed to undo: $e'));
      emit(currentState);
    }
  }
  
  Future<void> deleteEntry(int logId) async {
    if (state is! WaterIntakeLoaded) return;
    final currentState = state as WaterIntakeLoaded;
    
    try {
      await _service.deleteWaterLog(logId);
      // Reload to ensure correctness
      await loadData(_userId!);
    } catch (e) {
      emit(WaterIntakeError('Failed to delete: $e'));
      emit(currentState);
    }
  }

  Future<void> updateGoal(int newGoalMl) async {
    if (state is! WaterIntakeLoaded) return;
    final currentState = state as WaterIntakeLoaded;
    
    // Optimistic
    emit(WaterIntakeLoaded(
      currentIntakeMl: currentState.currentIntakeMl,
      dailyGoalMl: newGoalMl,
      todayLogs: currentState.todayLogs,
    ));

    try {
      await _service.setDailyGoal(newGoalMl);
    } catch (e) {
      // Rollback
      emit(currentState);
      emit(WaterIntakeError('Failed to update goal: $e'));
      emit(currentState);
    }
  }
}
