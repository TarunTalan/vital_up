import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/customize_layout_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/audio_track_picker_sheet.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'WORKOUT SETTINGS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: ValueListenableBuilder<WorkoutPrefs>(
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
                  _SectionHeader('SESSION'),

                  _SettingsTile(
                    icon: Icons.mic_rounded,
                    title: 'Voice coach',
                    subtitle: 'Audio cues at each km/mi milestone',
                    trailing: Switch(
                      value: prefs.voiceCoachEnabled,
                      activeColor: Colors.black,
                      onChanged: (v) => prefsNotifier.setVoiceCoach(v),
                    ),
                  ),

                  _SettingsTile(
                    icon: Icons.timer_3_rounded,
                    title: 'Countdown before start',
                    subtitle: '3-second countdown when you tap Start',
                    trailing: Switch(
                      value: prefs.countdownEnabled,
                      activeColor: Colors.black,
                      onChanged: (v) => prefsNotifier.setCountdown(v),
                    ),
                  ),

                  _SettingsTile(
                    icon: Icons.flag_rounded,
                    title: 'Workout target',
                    subtitle: targetSubtitle,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (prefs.targetType != WorkoutTargetType.none)
                          GestureDetector(
                            onTap: () => prefsNotifier.clearTarget(),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.cancel_outlined,
                                  color: Color(0xFFBBBBBB), size: 20),
                            ),
                          ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCCCCCC)),
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
                    icon: Icons.run_circle_outlined,
                    title: 'Default activity type',
                    subtitle: prefs.defaultActivityType.label,
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFCCCCCC)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'DEFAULT ACTIVITY TYPE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
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
                                  color: isSel ? Colors.black : Colors.grey,
                                ),
                                title: Text(
                                  type.label,
                                  style: TextStyle(
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    color: isSel ? Colors.black : Colors.black87,
                                  ),
                                ),
                                trailing: isSel
                                    ? const Icon(Icons.check_rounded, color: Colors.black)
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
                  _SectionHeader('DEVICES'),

                  _SettingsTile(
                    icon: connectedDevice != null
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor:
                        connectedDevice != null ? Colors.red : null,
                    title: 'Heart rate monitor',
                    subtitle: hrSubtitle,
                    trailing: connectedDevice != null
                        ? TextButton(
                            onPressed: () async {
                              await hrManager.disconnect();
                            },
                            child: const Text(
                              'Disconnect',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCCCCCC)),
                    onTap: connectedDevice != null
                        ? null
                        : () => HrDeviceSheet.show(context, hrManager),
                  ),

                  // ── Music & Stories ──────────────────────────────────────
                  _SectionHeader('MUSIC & STORIES'),

                  _SettingsTile(
                    icon: Icons.music_note_rounded,
                    title: 'Background soundtrack',
                    subtitle: prefs.backgroundAudioTrack == 'None'
                        ? 'No background soundtrack'
                        : prefs.backgroundAudioTrack,
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFCCCCCC)),
                    onTap: () => AudioTrackPickerSheet.show(
                      context,
                      current: prefs,
                      notifier: prefsNotifier,
                    ),
                  ),

                  // ── Display ──────────────────────────────────────────────
                  _SectionHeader('DISPLAY'),

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
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFCCCCCC)),
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
                  _SectionHeader('MAP'),

                  _OfflineMapTile(unitNotifier: unitNotifier, prefsNotifier: prefsNotifier),

                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
          color: Color(0xFF9A9A9A),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.black),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A))),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
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
                color: isSel ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                u.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSel ? Colors.white : const Color(0xFF888888),
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
      subtitle: 'Available on the tracking screen via the ⚙ button',
      trailing: const Icon(Icons.info_outline_rounded,
          color: Color(0xFFCCCCCC), size: 18),
    );
  }
}
