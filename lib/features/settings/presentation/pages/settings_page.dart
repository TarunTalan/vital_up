import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vital_up/features/feature_tips/data/feature_tips_service.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
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
import 'package:vital_up/core/utils/health_store.dart';

/// How the app behaves: appearance, units, notifications, connected apps,
/// privacy and about. Account and health items live under Profile.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _packageInfo = PackageInfo.fromPlatform();

  static const _themes = ['system', 'light', 'dark'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsCubit>().loadSettings();
    });
  }

  void _update(SettingsEntity settings) =>
      context.read<SettingsCubit>().updateSettings(settings);

  Future<void> _setHealthSync(SettingsEntity settings, bool on) async {
    var connected = true;
    if (on) {
      try {
        connected = await sl<HealthImportService>().connect();
      } catch (e) {
        debugPrint('Health connect failed: $e');
        connected = false;
      }
    }
    if (!connected) {
      if (mounted) {
        showErrorSnackBar(context, 'Allow health data access to turn this on.');
      }
      return;
    }
    if (!mounted) return;
    _update(settings.copyWith(healthSyncEnabled: on));
  }

  Future<void> _setAppLock(bool on) async {
    final success = await sl<BiometricAuthService>().setBiometricEnabled(on);
    if (!mounted) return;
    setState(() {});
    if (success) {
      showSuccessSnackBar(context, on ? 'App lock on' : 'App lock off');
    } else if (on) {
      showErrorSnackBar(context, 'Set up a screen lock on this device first.');
    }
  }

  /// Leaderboard visibility and city, the same sheet as in Arena.
  Future<void> _openLeaderboards() async {
    final cubit = sl<CommunityCubit>()..loadSettings();
    await CommunitySettingsSheet.show(context, cubit: cubit);
    await cubit.close();
  }

  static String _themeLabel(String mode) => switch (mode) {
    'light' => 'Light',
    'dark' => 'Dark',
    _ => 'System',
  };

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
            body: state is SettingsError
                ? LoadErrorView(
                    onRetry: context.read<SettingsCubit>().loadSettings,
                  )
                : const Center(child: VitalUpLoader()),
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
                selected: _themes.contains(s.themeMode)
                    ? s.themeMode
                    : 'system',
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
                    svgAsset: 'assets/icons/trackers/weight_icon.svg',
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
                  const _DistanceUnitTile(),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: sl<FeatureTipsService>().enabled,
                    builder: (context, on, _) => AppListTile(
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Feature tips',
                      subtitle:
                          'Now and then, something you may not have '
                          'tried',
                      trailing: Switch(
                        value: on,
                        onChanged: sl<FeatureTipsService>().setEnabled,
                      ),
                    ),
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
                    subtitle: healthStoreName,
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
                    onTap: _openLeaderboards,
                  ),
                  AppListTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI coach data',
                    subtitle: 'What Vita and AI plans may use',
                    onTap: () => context.pushNamed('ai-coach-data'),
                  ),
                  AppListTile(
                    icon: Icons.insights_rounded,
                    title: 'Share usage analytics',
                    subtitle: 'App opens and screens only. No health data.',
                    trailing: Switch(
                      value: s.analyticsEnabled,
                      onChanged: (on) =>
                          _update(s.copyWith(analyticsEnabled: on)),
                    ),
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

/// Distance in workouts (distance, pace, speed, targets). Kept in its own
/// preference, which the workout screens read when they open.
class _DistanceUnitTile extends StatefulWidget {
  const _DistanceUnitTile();

  @override
  State<_DistanceUnitTile> createState() => _DistanceUnitTileState();
}

class _DistanceUnitTileState extends State<_DistanceUnitTile> {
  final _unit = DistanceUnitNotifier();

  @override
  void initState() {
    super.initState();
    _unit.load();
  }

  @override
  void dispose() {
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DistanceUnit>(
      valueListenable: _unit,
      builder: (context, unit, _) => AppListTile(
        icon: Icons.route_rounded,
        title: 'Distance',
        trailing: AppSegmentedControl<DistanceUnit>(
          compact: true,
          values: DistanceUnit.values,
          selected: unit,
          label: (u) => u.label,
          onChanged: _unit.setUnit,
        ),
      ),
    );
  }
}
