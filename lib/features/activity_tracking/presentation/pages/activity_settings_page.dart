import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';

import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/customize_layout_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_audio_page.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Center(
            child: BackIcon(
              onClick: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Text(
          'ACTIVITY SETTINGS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: colors.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: ValueListenableBuilder<WorkoutPrefs>(
              valueListenable: prefsNotifier,
              builder: (_, prefs, __) {
                return ValueListenableBuilder<DistanceUnit>(
                  valueListenable: unitNotifier,
                  builder: (_, unit, __) {
                    final connectedDevice = hrManager.connectedDevice;

                    String targetSubtitle = 'No target set';
                    if (prefs.targetType == WorkoutTargetType.distance) {
                      final val = unit == DistanceUnit.miles
                          ? prefs.targetValue / 1.60934
                          : prefs.targetValue;
                      targetSubtitle =
                          '${val.toStringAsFixed(1)} ${unit.label}';
                    } else if (prefs.targetType == WorkoutTargetType.calories) {
                      targetSubtitle =
                          '${prefs.targetValue.toStringAsFixed(0)} kcal';
                    }

                    final hrSubtitle = connectedDevice != null
                        ? '${connectedDevice.platformName.isEmpty ? "Device" : connectedDevice.platformName}'
                            ' — ${liveHeartRate != null ? "$liveHeartRate BPM" : "connected"}'
                        : 'Tap to scan for BLE devices';

                    return ListView(
                      children: [
                        // ── Session ─────────────────────────────────────────────
                        const _SectionHeader('SESSION'),

                        _SettingsTile(
                          icon: Icons.mic_rounded,
                          title: 'Voice coach',
                          subtitle: 'Audio cues at each km/mi milestone',
                          trailing: Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: prefs.voiceCoachEnabled,
                              activeColor: colors.primary,
                              onChanged: (v) => prefsNotifier.setVoiceCoach(v),
                            ),
                          ),
                        ),

                        _SettingsTile(
                          icon: Icons.timer_3_rounded,
                          title: 'Countdown duration',
                          subtitle: prefs.countdownDurationSeconds == 0
                              ? 'Disabled'
                              : '${prefs.countdownDurationSeconds} seconds',
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: colors.outline),
                          onTap: () {
                            showSmoothDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(
                                  'COUNTDOWN DURATION',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: colors.onSurface,
                                  ),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [0, 3, 5, 10].map((sec) {
                                    final isSel = prefs.countdownDurationSeconds == sec;
                                    return ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      title: Text(
                                        sec == 0 ? 'Off' : '$sec seconds',
                                        style: TextStyle(
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          color: isSel ? colors.primary : colors.onSurface,
                                        ),
                                      ),
                                      trailing: isSel
                                          ? Icon(Icons.check_rounded, color: colors.primary)
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.outline.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    prefs.dailyTargetEnabled ? 'DAILY' : 'SESSION',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: customColors?.grayText ?? colors.onSurface.withValues(alpha: 0.6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              if (prefs.targetType != WorkoutTargetType.none)
                                GestureDetector(
                                  onTap: () => prefsNotifier.clearTarget(),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4, left: 4),
                                    child: Icon(Icons.cancel_outlined,
                                        color: colors.outline, size: 20),
                                  ),
                                ),
                              Icon(Icons.chevron_right_rounded,
                                  color: colors.outline),
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
                          icon: Icons.calendar_today_rounded,
                          title: 'Daily target',
                          subtitle: prefs.dailyTargetEnabled
                              ? (() {
                                  if (prefs.dailyTargetType == WorkoutTargetType.distance) {
                                    final val = unit == DistanceUnit.miles
                                        ? prefs.dailyTargetValue / 1.60934
                                        : prefs.dailyTargetValue;
                                    return '${val.toStringAsFixed(1)} ${unit.label} every session';
                                  } else if (prefs.dailyTargetType == WorkoutTargetType.calories) {
                                    return '${prefs.dailyTargetValue.toStringAsFixed(0)} kcal every session';
                                  }
                                  return 'Enabled';
                                })()
                              : 'Disabled — targets are per-session only',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (prefs.dailyTargetEnabled)
                                GestureDetector(
                                  onTap: () => prefsNotifier.clearDailyTarget(),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(Icons.cancel_outlined,
                                        color: colors.outline, size: 20),
                                  ),
                                ),
                              Icon(Icons.chevron_right_rounded,
                                  color: colors.outline),
                            ],
                          ),
                          onTap: () async {
                            final result = await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: colors.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
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
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: colors.outline),
                          onTap: () {
                            showSmoothDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(
                                  'DEFAULT ACTIVITY TYPE',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: colors.onSurface,
                                  ),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: ActivityType.values.map((type) {
                                    final isSel = prefs.defaultActivityType == type;
                                    return ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      leading: Icon(
                                        activityTypeIcon(type),
                                        color: isSel ? colors.primary : colors.outline,
                                      ),
                                      title: Text(
                                        type.label,
                                        style: TextStyle(
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          color: isSel ? colors.primary : colors.onSurface,
                                        ),
                                      ),
                                      trailing: isSel
                                          ? Icon(Icons.check_rounded, color: colors.primary)
                                          : null,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        prefsNotifier.setDefaultActivityType(type);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),

                        // ── Devices ──────────────────────────────────────────────
                        const _SectionHeader('DEVICES'),

                        _SettingsTile(
                          icon: connectedDevice != null
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor:
                              connectedDevice != null ? colors.error : null,
                          title: 'Heart rate monitor',
                          subtitle: hrSubtitle,
                          trailing: connectedDevice != null
                              ? TextButton(
                                  onPressed: () async {
                                    await hrManager.disconnect();
                                  },
                                  child: Text(
                                    'Disconnect',
                                    style: TextStyle(
                                        color: colors.error, fontSize: 12),
                                  ),
                                )
                              : Icon(Icons.chevron_right_rounded,
                                  color: colors.outline),
                          onTap: connectedDevice != null
                              ? null
                              : () => HrDeviceSheet.show(context, hrManager),
                        ),

                        // ── Music & Stories ──────────────────────────────────────
                        const _SectionHeader('MUSIC & STORIES'),

                        _SettingsTile(
                          icon: Icons.music_note_rounded,
                          title: 'Background soundtrack',
                          subtitle: prefs.backgroundAudioTrack == 'None'
                              ? 'No background soundtrack'
                              : prefs.backgroundAudioTrack,
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: colors.outline),
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
                        const _SectionHeader('DISPLAY'),

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
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: colors.outline),
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
                        const _SectionHeader('MAP'),

                        _OfflineMapTile(unitNotifier: unitNotifier, prefsNotifier: prefsNotifier),

                        const SizedBox(height: 32),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final customColors = theme.extension<VitalUpColors>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
          color: customColors?.grayText ?? const Color(0xFF9A9A9A),
        ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light 
            ? Colors.white.withValues(alpha: 0.72) 
            : colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: (theme.brightness == Brightness.light 
              ? const Color(0xFFD8D8D8) 
              : colors.outline).withValues(alpha: 0.72),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.outline.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? colors.onSurface),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: colors.onSurface)),
        subtitle: Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: customColors?.grayText ?? const Color(0xFF9A9A9A))),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Container(
      decoration: BoxDecoration(
        color: customColors?.tabBarBg ?? colors.outline.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DistanceUnit.values.map((u) {
          final isSel = u == selected;
          return GestureDetector(
            onTap: () => onTap(u),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                color: isSel ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                u.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSel ? (customColors?.buttonText ?? Colors.black) : (customColors?.grayText ?? const Color(0xFF888888)),
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
    final theme = Theme.of(context);
    return _SettingsTile(
      icon: Icons.download_for_offline_rounded,
      title: 'Download offline map',
      subtitle: 'Available on the tracking screen via the ⚙ button',
      trailing: Icon(Icons.info_outline_rounded,
          color: theme.colorScheme.outline, size: 18),
    );
  }
}

