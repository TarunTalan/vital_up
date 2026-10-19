import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/settings/data/datasources/settings_local_datasource_impl.dart';
import 'package:vital_up/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';

void main() {
  late SharedPreferences prefs;
  late SettingsLocalDataSourceImpl local;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = SettingsLocalDataSourceImpl(sharedPreferences: prefs);
  });

  test('analytics is on by default (older installs and backups)', () async {
    expect((await local.getSettings()).analyticsEnabled, isTrue);
  });

  test('analytics switch is saved and read back', () async {
    final off = (await local.getSettings()).copyWith(analyticsEnabled: false);
    await local.saveSettings(off);
    expect(prefs.getBool(SettingsLocalDataSourceImpl.keyAnalyticsEnabled), isFalse);
    expect((await local.getSettings()).analyticsEnabled, isFalse);
  });

  test('cubit applies the analytics switch on load and on change only', () async {
    final applied = <bool>[];
    final cubit = SettingsCubit(
      settingsRepository: SettingsRepositoryImpl(localDataSource: local),
      onAnalyticsChanged: (on) async => applied.add(on),
    );
    await cubit.loadSettings();
    expect(applied, [true]);

    final loaded = (cubit.state as SettingsLoaded).settings;
    await cubit.updateSettings(loaded.copyWith(themeMode: 'dark'));
    expect(applied, [true]);

    await cubit.updateSettings(loaded.copyWith(analyticsEnabled: false));
    expect(applied, [true, false]);
    await cubit.close();
  });
}
