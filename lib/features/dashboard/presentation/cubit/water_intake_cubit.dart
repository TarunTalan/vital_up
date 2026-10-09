import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import '../../data/services/water_intake_service.dart';
import 'water_intake_state.dart';

class WaterIntakeCubit extends Cubit<WaterIntakeState> {
  final WaterIntakeService _service;
  String? _userId;

  /// Day the loaded logs belong to; after midnight they are re-read.
  DateTime? _loadedDay;

  /// Millilitres added on screen but not yet saved (rapid taps).
  int _pendingMl = 0;

  WaterIntakeCubit(this._service) : super(WaterIntakeInitial());

  @override
  void emit(WaterIntakeState state) {
    // Saves can finish after the dashboard closed this cubit.
    if (!isClosed) super.emit(state);
  }

  /// Re-reads today's logs and goal, e.g. after the trends page edited them.
  Future<void> reload() async {
    if (_userId != null) await loadData(_userId!);
  }

  /// Loads today's logs. Already showing data, it refreshes in place
  /// instead of flashing the loading placeholder.
  Future<void> loadData(String userId) async {
    _userId = userId;
    if (state is! WaterIntakeLoaded) emit(WaterIntakeLoading());
    try {
      final goal = _service.getDailyGoal();
      final logs = await _service.getTodayLogs(userId).withLoadTimeout();
      _loadedDay = startOfDay(DateTime.now());
      emit(_loaded(logs, goal));
    } catch (e) {
      debugPrint('Water intake load failed: $e');
      if (state is! WaterIntakeLoaded) {
        emit(const WaterIntakeError(kLoadErrorMessage));
      }
    }
  }

  WaterIntakeLoaded _loaded(
    List<WaterLogCache> logs,
    int goal, {
    String? notice,
    int? addedMl,
  }) => WaterIntakeLoaded(
    currentIntakeMl:
        logs.fold<int>(0, (sum, log) => sum + log.amountMl) + _pendingMl,
    dailyGoalMl: goal,
    todayLogs: logs,
    notice: notice,
    addedMl: addedMl,
  );

  /// Re-emits the current logs (plus any pending adds), optionally with a
  /// one-off [notice] for the card to show.
  void _refresh({
    List<WaterLogCache>? logs,
    int? goal,
    String? notice,
    int? addedMl,
  }) {
    final s = state;
    if (s is! WaterIntakeLoaded) return;
    emit(
      _loaded(
        logs ?? s.todayLogs,
        goal ?? s.dailyGoalMl,
        notice: notice,
        addedMl: addedMl,
      ),
    );
  }

  bool get _isStale =>
      _loadedDay != null && !isSameDay(_loadedDay!, DateTime.now());

  /// Adds [amountMl] (shown straight away). Returns false when it couldn't
  /// be saved; the card is told through [WaterIntakeLoaded.notice].
  Future<bool> addWater(int amountMl) async {
    final userId = _userId;
    if (userId == null || state is! WaterIntakeLoaded) return false;
    if (amountMl < InputLimits.waterMlMin ||
        amountMl > InputLimits.waterMlMax) {
      return false;
    }
    // Past midnight: start today's total from today's logs.
    if (_isStale) await loadData(userId);

    _pendingMl += amountMl;
    _refresh();
    try {
      final newLog = await _service.addWaterLog(userId, amountMl);
      _pendingMl -= amountMl;
      final s = state;
      _refresh(
        logs: s is WaterIntakeLoaded ? [...s.todayLogs, newLog] : [newLog],
        addedMl: amountMl,
      );
      return true;
    } catch (e) {
      debugPrint('Add water failed: $e');
      _pendingMl -= amountMl;
      _refresh(notice: "Couldn't add water. Try again.");
      return false;
    }
  }

  Future<void> undoLast() async {
    final s = state;
    if (s is! WaterIntakeLoaded || s.todayLogs.isEmpty) return;
    final lastLog = s.todayLogs.last;
    try {
      // Not optimistic: putting a failed undo back would look like an add.
      await _service.deleteWaterLog(lastLog.id);
      final now = state;
      if (now is WaterIntakeLoaded) {
        _refresh(logs: [...now.todayLogs]..remove(lastLog));
      }
    } catch (e) {
      debugPrint('Undo water failed: $e');
      _refresh(notice: "Couldn't undo. Try again.");
    }
  }

  Future<void> deleteEntry(int logId) async {
    if (state is! WaterIntakeLoaded) return;
    try {
      await _service.deleteWaterLog(logId);
      await reload();
    } catch (e) {
      debugPrint('Delete water failed: $e');
      _refresh(notice: "Couldn't delete that entry. Try again.");
    }
  }

  Future<void> updateGoal(int newGoalMl) async {
    final s = state;
    if (s is! WaterIntakeLoaded) return;
    final goal = newGoalMl.clamp(
      InputLimits.waterGoalMlMin,
      InputLimits.waterGoalMlMax,
    );
    _refresh(goal: goal);
    try {
      await _service.setDailyGoal(goal);
    } catch (e) {
      debugPrint('Water goal not saved: $e');
      _refresh(goal: s.dailyGoalMl, notice: "Couldn't save your goal. Try again.");
    }
  }
}
