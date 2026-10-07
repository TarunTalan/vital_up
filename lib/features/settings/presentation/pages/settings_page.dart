import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/services/biometric_auth_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_leaderboards_section.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';

/// How the app behaves: appearance, units, notifications, connected apps,
/// privacy and about. Account and health items live under Profile.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _packageInfo = PackageInfo.fromPlatform();
  bool _openingLeaderboards = false;

  static const _themes = ['system', 'light', 'dark'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsCubit>().loadSettings();
    });
  }

  void _update(SettingsEntity settings) =>
      context.read<SettingsCubit>().updateSettings(settings);

  Future<void> _setHealthSync(SettingsEntity settings, bool on) async {
    if (on && !await sl<HealthImportService>().connect()) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Allow VitalUp to read weight and workouts in '
          'Health Connect / Apple Health to turn this on.',
        );
      }
      return;
    }
    _update(settings.copyWith(healthSyncEnabled: on));
  }

  Future<void> _setAppLock(bool on) async {
    final success = await sl<BiometricAuthService>().setBiometricEnabled(on);
    if (!mounted) return;
    setState(() {});
    if (success) {
      showSuccessSnackBar(context, on ? 'App lock on' : 'App lock off');
    } else if (on) {
      showErrorSnackBar(
        context,
        "Couldn't turn on app lock. Check that this device has a "
        'fingerprint, face or PIN set up.',
      );
    }
  }

  /// Leaderboard visibility and city, the same sheet as in Arena.
  Future<void> _openLeaderboards() async {
    if (_openingLeaderboards) return;
    setState(() => _openingLeaderboards = true);
    final cubit = sl<CommunityCubit>();
    await cubit.load();
    if (!mounted) {
      await cubit.close();
      return;
    }
    setState(() => _openingLeaderboards = false);
    if (cubit.state.failed) {
      showErrorSnackBar(context, "Couldn't load your leaderboard settings.");
    } else {
      await CommunitySettingsSheet.show(context, cubit: cubit);
    }
    await cubit.close();
  }

  static String _themeLabel(String mode) => switch (mode) {
    'light' => 'Light',
    'dark' => 'Dark',
    _ => 'System',
  };

  Widget _chevronSpinner() => SizedBox.square(
    dimension: AppDimens.iconMd,
    child: CircularProgressIndicator(
      strokeWidth: AppDimens.borderThick,
      color: context.colors.primary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    const header = AppPageHeader(title: 'Settings');

    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsError) showErrorSnackBar(context, state.message);
      },
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return AppScaffold(
            header: header,
            body: Padding(
              padding: const EdgeInsets.only(top: AppDimens.space48),
              child: state is SettingsError
                  ? LoadErrorView(
                      onRetry: context.read<SettingsCubit>().loadSettings,
                    )
                  : const Center(child: VitalUpLoader()),
            ),
          );
        }
        final s = state.settings;
        final v = context.vColors;

        return AppScaffold(
          header: header,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader('Appearance'),
              AppSegmentedControl<String>(
                values: _themes,
                selected: _themes.contains(s.themeMode) ? s.themeMode : 'system',
                label: _themeLabel,
                onChanged: (mode) => _update(s.copyWith(themeMode: mode)),
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'Units',
                children: [
                  AppListTile(
                    icon: Icons.straighten_rounded,
                    title: 'Height',
                    trailing: AppSegmentedControl<String>(
                      compact: true,
                      values: const ['cm', 'in'],
                      selected: s.heightUnit,
                      label: (unit) => unit == 'in' ? 'ft / in' : unit,
                      onChanged: (unit) =>
                          _update(s.copyWith(heightUnit: unit)),
                    ),
                  ),
                  AppListTile(
                    icon: Icons.monitor_weight_rounded,
                    title: 'Weight',
                    trailing: AppSegmentedControl<String>(
                      compact: true,
                      values: const ['kg', 'lbs'],
                      selected: s.weightUnit,
                      label: (unit) => unit,
                      onChanged: (unit) =>
                          _update(s.copyWith(weightUnit: unit)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'Notifications',
                children: [
                  AppListTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Push notifications',
                    subtitle: 'Insights, friends and challenges',
                    trailing: Switch(
                      value: s.notificationsEnabled,
                      onChanged: (on) =>
                          _update(s.copyWith(notificationsEnabled: on)),
                    ),
                  ),
                  AppListTile(
                    icon: Icons.alarm_rounded,
                    iconColor: v.warning,
                    title: 'Reminders',
                    subtitle: 'Meals, water, sleep, activity',
                    onTap: () => context.pushNamed('reminders'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'Connected',
                children: [
                  AppListTile(
                    icon: Icons.sync_rounded,
                    iconColor: v.success,
                    title: 'Health sync',
                    subtitle: 'Health Connect / Apple Health',
                    trailing: Switch(
                      value: s.healthSyncEnabled,
                      onChanged: (on) => _setHealthSync(s, on),
                    ),
                  ),
                  AppListTile(
                    icon: Icons.widgets_rounded,
                    title: 'Home screen widgets',
                    subtitle: 'Live previews and quick actions',
                    onTap: () => context.pushNamed('home-widgets'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'Privacy & security',
                children: [
                  AppListTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'App lock',
                    subtitle: 'Fingerprint, Face ID or PIN',
                    trailing: Switch(
                      value: sl<BiometricAuthService>().isBiometricEnabled(),
                      onChanged: _setAppLock,
                    ),
                  ),
                  AppListTile(
                    icon: Icons.leaderboard_rounded,
                    iconColor: AppColors.scoreBonus,
                    title: 'Leaderboards',
                    subtitle: 'Who sees you, and your city',
                    trailing: _openingLeaderboards ? _chevronSpinner() : null,
                    onTap: _openLeaderboards,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'About',
                children: [
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snap) => AppListTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About VitalUp',
                      value: snap.hasData
                          ? '${snap.data!.version} (${snap.data!.buildNumber})'
                          : null,
                      onTap: () => context.pushNamed('about'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
