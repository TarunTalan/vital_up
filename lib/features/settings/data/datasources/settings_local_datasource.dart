import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';

abstract class SettingsLocalDataSource {
  Future<SettingsEntity> getSettings();
  Future<void> saveSettings(SettingsEntity settings);
}
