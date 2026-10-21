import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';

import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/customize_layout_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/hr_device_sheet.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/target_picker_sheet.dart';

/// Full-screen settings page for activity tracking preferences.
///
/// Receives shared [DistanceUnitNotifier], [WorkoutPrefsNotifier] and
/// [HeartRateManager] from the tracking page via the extra argument so
/// the live session isn't disrupted when settings change.
class ActivitySettingsPage extends StatelessWidget {
  final DistanceUnitNotifier unitNotifier;
  final WorkoutPrefsNotifier prefsNotifier;
  final HeartRateManager hrManager;
  final int? liveHeartRate;

  /// The activity the settings are for: a workout without a route gets a
  /// time or calories target and no map or GPS layout rows.
  final ActivityType activityType;

  const ActivitySettingsPage({
    super.key,
    required this.unitNotifier,
    required this.prefsNotifier,
    required this.hrManager,
    this.liveHeartRate,
    this.activityType = ActivityType.walk,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chevron = const AppChevron();

    return AppScaffold(
      header: AppPageHeader(title: 'Activity Settings'),
      scrollable: false,
      padBody: false,
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<WorkoutPrefs>(
          valueListenable: prefsNotifier,
          builder: (_, prefs, _) {
            return ValueListenableBuilder<DistanceUnit>(
              valueListenable: unitNotifier,
              builder: (_, unit, _) {
                final connectedDevice = hrManager.connectedDevice;

                final timed = !activityType.isGpsBased;
                String targetSubtitle = "Not set: what's left of today's goal";
                if (timed) {
                  targetSubtitle = switch (prefs.timerTargetType) {
                    WorkoutTargetType.duration =>
                      '${prefs.timerTargetValue.toStringAsFixed(0)} min',
                    WorkoutTargetType.calories =>
                      '${prefs.timerTargetValue.toStringAsFixed(0)} kcal',
                    _ => targetSubtitle,
                  };
                } else if (prefs.targetType == WorkoutTargetType.distance) {
                  final val = unit == DistanceUnit.miles
                      ? prefs.targetValue / 1.60934
                      : prefs.targetValue;
                  targetSubtitle = '${val.toStringAsFixed(1)} ${unit.label}';
                } else if (prefs.targetType == WorkoutTargetType.calories) {
                  targetSubtitle =
                      '${prefs.targetValue.toStringAsFixed(0)} kcal';
                }

                final hrSubtitle = connectedDevice != null
                    ? '${connectedDevice.platformName.isEmpty ? "Device" : connectedDevice.platformName}'
                          ' — ${liveHeartRate != null ? "$liveHeartRate BPM" : "connected"}'
                    : 'Tap to scan for BLE devices';

                return ListView(
                  padding: const EdgeInsets.only(bottom: AppDimens.space32),
                  children: [
                    // ── Session ─────────────────────────────────────────────
                    const _SectionHeader('Session'),

                    _SettingsTile(
                      icon: Icons.mic_rounded,
                      title: 'Voice coach',
                      subtitle: timed
                          ? 'Time, calories and goal progress every 5 min'
                          : 'Audio cues at each km/mi milestone',
                      trailing: Switch(
                        value: prefs.voiceCoachEnabled,
                        onChanged: (v) => prefsNotifier.setVoiceCoach(v),
                      ),
                    ),

                    _SettingsTile(
                      icon: Icons.timer_3_rounded,
                      title: 'Countdown duration',
                      subtitle: prefs.countdownDurationSeconds == 0
                          ? 'Disabled'
                          : '${prefs.countdownDurationSeconds} seconds',
                      trailing: chevron,
                      onTap: () {
                        showSmoothDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Countdown duration'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [0, 3, 5, 10].map((sec) {
                                final isSel =
                                    prefs.countdownDurationSeconds == sec;
                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusSm,
                                    ),
                                  ),
                                  title: Text(
                                    sec == 0 ? 'Off' : '$sec seconds',
                                    style: context.text.bodyLarge?.copyWith(
                                      fontWeight: isSel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSel
                                          ? colors.primary
                                          : colors.onSurface,
                                    ),
                                  ),
                                  trailing: isSel
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: colors.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    prefsNotifier.setCountdownDuration(sec);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),

                    _SettingsTile(
                      icon: Icons.flag_rounded,
                      title: 'Activity target',
                      subtitle: targetSubtitle,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((timed
                                  ? prefs.timerTargetType
                                  : prefs.targetType) !=
                              WorkoutTargetType.none)
                            _ClearButton(
                              onTap: () => timed
                                  ? prefsNotifier.clearTimerTarget()
                                  : prefsNotifier.clearTarget(),
                            ),
                          chevron,
                        ],
                      ),
                      onTap: () async {
                        await TargetPickerSheet.show(
                          context,
                          current: prefs,
                          distanceUnit: unit,
                          notifier: prefsNotifier,
                          timed: timed,
                        );
                      },
                    ),

                    // ── Devices ──────────────────────────────────────────────
                    const _SectionHeader('Devices'),

                    _SettingsTile(
                      icon: connectedDevice != null
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: connectedDevice != null ? colors.error : null,
                      title: 'Heart rate monitor',
                      subtitle: hrSubtitle,
                      trailing: connectedDevice != null
                          ? TextButton(
                              onPressed: () async {
                                await hrManager.disconnect();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: colors.error,
                                textStyle: context.text.bodySmall,
                              ),
                              child: const Text('Disconnect'),
                            )
                          : chevron,
                      onTap: connectedDevice != null
                          ? null
                          : () => HrDeviceSheet.show(context, hrManager),
                    ),

                    // The live stats layout and the map are GPS only.
                    if (!timed) ...[
                      // ── Display ──────────────────────────────────────────────
                      const _SectionHeader('Display'),

                      _SettingsTile(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Customize metrics layout',
                        subtitle: 'Choose and reorder stats on tracking page',
                        trailing: chevron,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomizeLayoutPage(
                                prefsNotifier: prefsNotifier,
                              ),
                            ),
                          );
                        },
                      ),

                      // ── Map ─────────────────────────────────────────────────
                      const _SectionHeader('Map'),

                      _OfflineMapTile(
                        unitNotifier: unitNotifier,
                        prefsNotifier: prefsNotifier,
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Private helpers ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.sectionGap,
        context.gutter,
        AppDimens.space8,
      ),
      child: AppCaption(title),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Clear',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Icons.cancel_rounded,
        color: context.vColors.grayText,
        size: AppDimens.iconMd,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.symmetric(
        horizontal: context.gutter,
        vertical: AppDimens.space4,
      ),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
          vertical: AppDimens.space4,
        ),
        leading: AppIconBadge(icon: Icon(icon), color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _OfflineMapTile extends StatefulWidget {
  final DistanceUnitNotifier unitNotifier;
  final WorkoutPrefsNotifier prefsNotifier;

  const _OfflineMapTile({
    required this.unitNotifier,
    required this.prefsNotifier,
  });

  @override
  State<_OfflineMapTile> createState() => _OfflineMapTileState();
}

class _OfflineMapTileState extends State<_OfflineMapTile> {
  // Offline map state is managed in the tracking page, so this tile
  // is informational here — it directs the user back to the tracking page.
  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.download_for_offline_rounded,
      title: 'Download offline map',
      subtitle: 'Available on the tracking screen via the settings button',
      trailing: Icon(
        Icons.info_outline_rounded,
        color: context.vColors.grayText,
        size: AppDimens.iconSm,
      ),
    );
  }
}
