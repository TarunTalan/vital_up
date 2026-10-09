import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import '../../data/services/screen_time_service.dart';
import '../../domain/entities/app_usage_info.dart';
import 'screen_time_state.dart';

class ScreenTimeCubit extends Cubit<ScreenTimeState> with WidgetsBindingObserver {
  final ScreenTimeService _service;

  ScreenTimeCubit(this._service) : super(ScreenTimeInitial()) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void emit(ScreenTimeState state) {
    if (!isClosed) super.emit(state);
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadStats();
    }
  }

  /// Already showing figures, it refreshes in place (no placeholder flash
  /// on every app resume).
  Future<void> loadStats() async {
    if (state is! ScreenTimeLoaded) emit(ScreenTimeLoading());
    try {
      final hasPermission = await _service.hasPermission().withLoadTimeout();
      if (!hasPermission) {
        emit(ScreenTimePermissionDenied());
        return;
      }

      final stats = await _service.getUsageStats().withLoadTimeout();
      
      Duration total = Duration.zero;
      for (var stat in stats) {
        total += stat.usageDuration;
      }

      ScreenTimeWeeklySummary? summary;
      try {
        summary = await _service.getWeeklySummary().withLoadTimeout();
      } catch (e) {
        debugPrint('Weekly screen time summary failed: $e');
      }
      
      emit(ScreenTimeLoaded(
        usageStats: stats,
        totalDuration: total,
        weeklySummary: summary,
      ));
    } catch (e) {
      debugPrint('Screen time load failed: $e');
      if (state is! ScreenTimeLoaded) {
        emit(const ScreenTimeError(kLoadErrorMessage));
      }
    }
  }

  Future<void> openSettings() async {
    try {
      await _service.openSettings();
    } catch (e) {
      debugPrint('Usage access settings unavailable: $e');
    }
  }
}
