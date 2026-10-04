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
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_audio_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_target_result.dart';
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

  const ActivitySettingsPage({
    super.key,
    required this.unitNotifier,
    required this.prefsNotifier,
    required this.hrManager,
    this.liveHeartRate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chevron = Icon(
      Icons.chevron_right_rounded,
      color: context.vColors.grayText,
    );

    return AppScaffold(
      header: const AppPageHeader(title: 'Activity Settings'),
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

                String targetSubtitle = 'No target set';
                if (prefs.targetType == WorkoutTargetType.distance) {
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
                      subtitle: 'Audio cues at each km/mi milestone',
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
                          if (prefs.targetType != WorkoutTargetType.none)
                            ActivityTagChip(
                              label: prefs.dailyTargetEnabled
                                  ? 'Daily'
                                  : 'Session',
                            ),
                          if (prefs.targetType != WorkoutTargetType.none)
                            _ClearButton(
                              onTap: () => prefsNotifier.clearTarget(),
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
                        );
                      },
                    ),

                    _SettingsTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'Daily target',
                      subtitle: prefs.dailyTargetEnabled
                          ? (() {
                              if (prefs.dailyTargetType ==
                                  WorkoutTargetType.distance) {
                                final val = unit == DistanceUnit.miles
                                    ? prefs.dailyTargetValue / 1.60934
                                    : prefs.dailyTargetValue;
                                return '${val.toStringAsFixed(1)} ${unit.label} every session';
                              } else if (prefs.dailyTargetType ==
                                  WorkoutTargetType.calories) {
                                return '${prefs.dailyTargetValue.toStringAsFixed(0)} kcal every session';
                              }
                              return 'Enabled';
                            })()
                          : 'Disabled — targets are per-session only',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (prefs.dailyTargetEnabled)
                            _ClearButton(
                              onTap: () => prefsNotifier.clearDailyTarget(),
                            ),
                          chevron,
                        ],
                      ),
                      onTap: () async {
                        final result =
                            await showAppBottomSheet<
                              (WorkoutTargetType, double)?
                            >(
                              context: context,
                              builder: (_) => TargetPickerSheet(
                                current: prefs.dailyTargetEnabled
                                    ? prefs.copyWith(
                                        targetType: prefs.dailyTargetType,
                                        targetValue: prefs.dailyTargetValue,
                                      )
                                    : prefs.copyWith(
                                        targetType: WorkoutTargetType.none,
                                        targetValue: 0.0,
                                      ),
                                distanceUnit: unit,
                              ),
                            );
                        if (result != null) {
                          final (WorkoutTargetType type, double val) = result;
                          await prefsNotifier.setDailyTarget(type, val);
                        }
                      },
                    ),

                    _SettingsTile(
                      icon: Icons.run_circle_outlined,
                      title: 'Default activity type',
                      subtitle: prefs.defaultActivityType.label,
                      trailing: chevron,
                      onTap: () {
                        showSmoothDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Default activity type'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: ActivityType.values.map((type) {
                                  final isSel =
                                      prefs.defaultActivityType == type;
                                  return ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusSm,
                                      ),
                                    ),
                                    leading: Icon(
                                      activityTypeIcon(type),
                                      color: isSel
                                          ? colors.primary
                                          : context.vColors.grayText,
                                    ),
                                    title: Text(
                                      type.label,
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
                                      prefsNotifier.setDefaultActivityType(
                                        type,
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
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

                    // ── Music & Stories ──────────────────────────────────────
                    const _SectionHeader('Music & stories'),

                    _SettingsTile(
                      icon: Icons.music_note_rounded,
                      title: 'Background soundtrack',
                      subtitle: prefs.backgroundAudioTrack == 'None'
                          ? 'No background soundtrack'
                          : prefs.backgroundAudioTrack,
                      trailing: chevron,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutAudioPage(
                            current: prefs,
                            notifier: prefsNotifier,
                          ),
                        ),
                      ),
                    ),

                    // ── Display ──────────────────────────────────────────────
                    const _SectionHeader('Display'),

                    _SettingsTile(
                      icon: Icons.straighten_rounded,
                      title: 'Distance unit',
                      subtitle: 'Affects distance, pace and speed display',
                      trailing: _UnitPill(
                        selected: unit,
                        onTap: (u) => unitNotifier.setUnit(u),
                      ),
                    ),

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
        Icons.cancel_outlined,
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

class _UnitPill extends StatelessWidget {
  final DistanceUnit selected;
  final ValueChanged<DistanceUnit> onTap;

  const _UnitPill({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;

    return Container(
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: v.glassBorder!),
      ),
      padding: const EdgeInsets.all(AppDimens.space2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DistanceUnit.values.map((u) {
          final isSel = u == selected;
          return GestureDetector(
            onTap: () => onTap(u),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space12,
                vertical: AppDimens.space4,
              ),
              decoration: BoxDecoration(
                color: isSel ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: Text(
                u.label.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSel ? v.buttonText : v.grayText,
                ),
              ),
            ),
          );
        }).toList(),
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
