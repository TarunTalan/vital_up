import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final SharedPreferences sharedPreferences;

  SettingsLocalDataSourceImpl({required this.sharedPreferences});

  static const String _keyThemeMode = 'settings_theme_mode';
  static const String _keyNotificationsEnabled = 'settings_notifications_enabled';
  static const String _keyHealthSyncEnabled = 'settings_health_sync_enabled';
  static const String _keyWeightUnit = 'settings_weight_unit';
  static const String _keyHeightUnit = 'settings_height_unit';

  @override
  Future<SettingsEntity> getSettings() async {
    // Unknown stored values (older builds, edits) fall back to defaults.
    final themeMode = _oneOf(_keyThemeMode, const ['system', 'light', 'dark'], 'system');
    final notificationsEnabled = sharedPreferences.getBool(_keyNotificationsEnabled) ?? true;
    final healthSyncEnabled = sharedPreferences.getBool(_keyHealthSyncEnabled) ?? false;
    final weightUnit = _oneOf(_keyWeightUnit, const ['kg', 'lbs'], 'kg');
    final heightUnit = _oneOf(_keyHeightUnit, const ['cm', 'in'], 'cm');

    return SettingsEntity(
      themeMode: themeMode,
      notificationsEnabled: notificationsEnabled,
      healthSyncEnabled: healthSyncEnabled,
      weightUnit: weightUnit,
      heightUnit: heightUnit,
    );
  }

  String _oneOf(String key, List<String> allowed, String fallback) {
    final value = sharedPreferences.getString(key);
    return value != null && allowed.contains(value) ? value : fallback;
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    await sharedPreferences.setString(_keyThemeMode, settings.themeMode);
    await sharedPreferences.setBool(_keyNotificationsEnabled, settings.notificationsEnabled);
    await sharedPreferences.setBool(_keyHealthSyncEnabled, settings.healthSyncEnabled);
    await sharedPreferences.setString(_keyWeightUnit, settings.weightUnit);
    await sharedPreferences.setString(_keyHeightUnit, settings.heightUnit);
  }
}
