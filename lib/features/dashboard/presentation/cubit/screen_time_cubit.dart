import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import '../../data/services/screen_time_service.dart';
import 'screen_time_state.dart';

class ScreenTimeCubit extends Cubit<ScreenTimeState> with WidgetsBindingObserver {
  final ScreenTimeService _service;

  ScreenTimeCubit(this._service) : super(ScreenTimeInitial()) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh stats when app comes back to foreground (e.g. after granting permissions)
      loadStats();
    }
  }

  Future<void> loadStats() async {
    emit(ScreenTimeLoading());
    try {
      final hasPermission = await _service.hasPermission();
      if (!hasPermission) {
        emit(ScreenTimePermissionDenied());
        return;
      }

      final stats = await _service.getUsageStats();
      
      Duration total = Duration.zero;
      for (var stat in stats) {
        total += stat.usageDuration;
      }
      
      emit(ScreenTimeLoaded(usageStats: stats, totalDuration: total));
    } catch (e) {
      emit(ScreenTimeError(e.toString()));
    }
  }

  Future<void> openSettings() async {
    await _service.openSettings();
  }
}
