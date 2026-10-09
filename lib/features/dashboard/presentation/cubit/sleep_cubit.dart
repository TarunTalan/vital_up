import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import '../../data/services/sleep_service.dart';
import '../../domain/entities/sleep_session_info.dart';
import 'sleep_state.dart';
import 'dart:io';

/// Shown when a night couldn't be saved.
const _saveError = "Couldn't save your sleep. Try again.";

class SleepCubit extends Cubit<SleepState> with WidgetsBindingObserver {
  final SleepService _service;
  late final StreamSubscription<void> _changes;

  SleepCubit(this._service) : super(SleepInitial()) {
    WidgetsBinding.instance.addObserver(this);
    // Saves and bedtimes from anywhere (sheets, notification actions).
    _changes = _service.changes.listen(
      (_) => loadSleepData(requestPermission: false, silent: true),
    );
  }

  @override
  void emit(SleepState state) {
    // Loads can finish after the cubit closed (sign-out, dashboard gone).
    if (!isClosed) super.emit(state);
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _changes.cancel();
    return super.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _staleOnResume) {
      // Never prompt here: closing a permission screen resumes the app.
      loadSleepData(requestPermission: false, silent: true);
    }
  }

  /// Worth re-reading when the user comes back: they may have installed
  /// Health Connect, granted usage access, or woken up since.
  bool get _staleOnResume => switch (state) {
    SleepLoading() || SleepInitial() => false,
    SleepLoadedAuto(:final session) ||
    SleepLoadedManual(:final session) => !isSameDay(
      session.wakeTime,
      DateTime.now(),
    ),
    _ => true,
  };

  /// Last night from Health Connect or a saved entry, else a phone estimate
  /// to confirm; while a "Going to bed" is open, the in-bed state.
  /// [silent] skips the loading state (background refreshes).
  Future<void> loadSleepData({
    bool requestPermission = true,
    bool silent = false,
  }) async {
    if (!silent) emit(SleepLoading());
    try {
      final session = await _service.getSleepDataForLastNight(
        requestPermission: requestPermission,
      );
      final bed = await _service.pendingBedtime();
      if (bed != null && (session == null || bed.isAfter(session.wakeTime))) {
        // Screen data beats the tap once they're up: it knows when they
        // actually fell asleep and woke.
        final estimate = await _service.estimateLastNight();
        emit(
          estimate != null && estimate.wakeTime.isAfter(bed)
              ? SleepNeedsConfirmation(estimate)
              : SleepInBed(bed),
        );
        return;
      }
      // A watch already recorded the night the tap started.
      if (bed != null) unawaited(_service.cancelBedtime());
      if (session != null) {
        emit(
          session.source == SleepDataSource.healthStore
              ? SleepLoadedAuto(session)
              : SleepLoadedManual(session),
        );
        return;
      }

      final estimate = await _service.estimateLastNight();
      if (estimate != null) {
        emit(SleepNeedsConfirmation(estimate));
        return;
      }

      if (Platform.isAndroid) {
        final status = await _service.getHealthConnectStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable ||
            status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          emit(SleepNeedsHealthConnectInstall());
          return;
        }
      }

      emit(
        SleepNeedsManualEntry(
          canDetect: !Platform.isAndroid || await _service.canEstimateFromPhone(),
        ),
      );
    } catch (e) {
      debugPrint('Sleep load failed: $e');
      emit(const SleepError(kLoadErrorMessage));
    }
  }

  Future<void> saveManualSleep(DateTime bedTime, DateTime wakeTime) async {
    emit(SleepLoading());
    try {
      final session = await _service.saveManualEntry(bedTime, wakeTime);
      emit(SleepLoadedManual(session));
    } catch (e) {
      debugPrint('Sleep entry not saved: $e');
      emit(const SleepError(_saveError));
    }
  }

  /// Saves the phone's estimate of last night as-is. Returns false (state
  /// unchanged) when it couldn't be saved.
  Future<bool> confirmEstimate() async {
    final current = state;
    if (current is! SleepNeedsConfirmation) return false;
    final e = current.estimate;
    try {
      final session = await _service.saveManualEntry(
        e.bedTime,
        e.wakeTime,
        source: SleepDataSource.phone,
        asleep: e.duration,
      );
      emit(SleepLoadedManual(session));
      return true;
    } catch (err) {
      debugPrint('Sleep estimate not saved: $err');
      return false;
    }
  }

  /// "Going to bed" from the app. False when it couldn't be saved.
  Future<bool> goToBed() => _attempt(_service.markBedtime, 'Bedtime');

  /// "I'm up": saves the night since the bedtime tap. False (state
  /// unchanged) when it couldn't be saved.
  Future<bool> wakeUp() => _attempt(_service.wakeUp, 'Wake-up');

  Future<bool> cancelBedtime() =>
      _attempt(_service.cancelBedtime, 'Cancel bedtime');

  /// Runs a quick sleep action; the service's change stream refreshes the
  /// card on success.
  Future<bool> _attempt(Future<Object?> Function() action, String what) async {
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('$what failed: $e');
      return false;
    }
  }

  Future<void> installHealthConnect() async {
    await _service.installHealthConnect();
  }

  void showManualEntryForm() {
    emit(const SleepNeedsManualEntry());
  }
}
