import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _settingsRepository;

  SettingsCubit({
    required SettingsRepository settingsRepository,
  })  : _settingsRepository = settingsRepository,
        super(SettingsInitial());

  Future<void> loadSettings() async {
    emit(SettingsLoading());
    final Either<Failure, SettingsEntity> result;
    try {
      result = await _settingsRepository.getSettings().withLoadTimeout();
    } catch (_) {
      if (!isClosed) emit(const SettingsError(kLoadErrorMessage));
      return;
    }
    if (isClosed) return;
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (settings) => emit(SettingsLoaded(settings)),
    );
  }

  Future<void> updateSettings(SettingsEntity settings) async {
    final result = await _settingsRepository.saveSettings(settings);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => emit(SettingsLoaded(settings)),
    );
  }
}
