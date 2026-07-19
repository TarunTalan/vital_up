import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import '../../data/services/sleep_service.dart';
import '../../domain/entities/sleep_session_info.dart';
import 'sleep_state.dart';
import 'dart:io';

class SleepCubit extends Cubit<SleepState> with WidgetsBindingObserver {
  final SleepService _service;

  SleepCubit(this._service) : super(SleepInitial()) {
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
      if (this.state is SleepNeedsHealthConnectInstall || this.state is SleepError) {
        loadSleepData();
      }
    }
  }

  Future<void> loadSleepData() async {
    emit(SleepLoading());
    try {
      if (Platform.isAndroid) {
        final status = await _service.getHealthConnectStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable || 
            status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          emit(SleepNeedsHealthConnectInstall());
          return;
        }
      }

      final session = await _service.getSleepDataForLastNight();
      
      if (session != null) {
        if (session.source == SleepDataSource.healthStore) {
          emit(SleepLoadedAuto(session));
        } else {
          emit(SleepLoadedManual(session));
        }
      } else {
        emit(SleepNeedsManualEntry());
      }
    } catch (e) {
      emit(SleepError(e.toString()));
    }
  }

  Future<void> saveManualSleep(DateTime bedTime, DateTime wakeTime) async {
    emit(SleepLoading());
    try {
      final session = await _service.saveManualEntry(bedTime, wakeTime);
      emit(SleepLoadedManual(session));
    } catch (e) {
      emit(SleepError(e.toString()));
    }
  }
  
  Future<void> installHealthConnect() async {
    await _service.installHealthConnect();
  }
  
  void showManualEntryForm() {
    emit(SleepNeedsManualEntry());
  }
}
