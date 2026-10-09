import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _settingsRepository;

  /// Called when the notifications switch changes (push on/off).
  final Future<void> Function(bool enabled)? _onNotificationsChanged;

  SettingsCubit({
    required SettingsRepository settingsRepository,
    this._onNotificationsChanged,
  })  : _settingsRepository = settingsRepository,
        super(SettingsInitial());

  Future<void> loadSettings() async {
    // Already loaded: refresh quietly. Emitting Loading here dropped the
    // app theme (read from this cubit) back to System for a frame.
    final loaded = state is SettingsLoaded;
    if (!loaded) emit(SettingsLoading());
    final Either<Failure, SettingsEntity> result;
    try {
      result = await _settingsRepository.getSettings().withLoadTimeout();
    } catch (_) {
      if (!isClosed && !loaded) emit(const SettingsError(kLoadErrorMessage));
      return;
    }
    if (isClosed) return;
    result.fold(
      (failure) {
        if (!loaded) emit(SettingsError(failure.message));
      },
      (settings) => emit(SettingsLoaded(settings)),
    );
  }

  Future<void> updateSettings(SettingsEntity settings) async {
    final current = state is SettingsLoaded
        ? (state as SettingsLoaded).settings
        : null;
    final previous = current?.notificationsEnabled;
    final result = await _settingsRepository.saveSettings(settings);
    if (isClosed) return;
    result.fold(
      (failure) {
        // Report it, then keep the page (and theme) on the saved values.
        emit(SettingsError(failure.message));
        if (current != null) emit(SettingsLoaded(current));
      },
      (_) => emit(SettingsLoaded(settings)),
    );
    if (result.isRight() && previous != settings.notificationsEnabled) {
      try {
        await _onNotificationsChanged?.call(settings.notificationsEnabled);
      } catch (e) {
        debugPrint('Notification preference not applied: $e');
      }
    }
  }
}
