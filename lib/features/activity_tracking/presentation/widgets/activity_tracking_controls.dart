import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';


/// Row of activity type buttons (walk/run/cycle/more) shown while idle.
class ActivitySelector extends StatelessWidget {
  final ActivityType selected;
  final bool enabled;
  final ValueChanged<ActivityType> onSelected;

  const ActivitySelector({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ActivityButton(
          icon: Icons.directions_walk_rounded,
          selected: selected == ActivityType.walk,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.walk),
        ),
        const SizedBox(width: 8),
        ActivityButton(
          icon: Icons.directions_run_rounded,
          selected: selected == ActivityType.run,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.run),
        ),
        const SizedBox(width: 8),
        ActivityButton(
          icon: Icons.directions_bike_rounded,
          selected: selected == ActivityType.cycle,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.cycle),
        ),
        const SizedBox(width: 8),
        MoreActivitiesButton(
          enabled: enabled,
          selected: selected,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class ActivityButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const ActivityButton({
    super.key,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.12)
                : (theme.brightness == Brightness.light
                    ? Colors.white.withValues(alpha: 0.72)
                    : colors.surface.withValues(alpha: 0.72)),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : (theme.brightness == Brightness.light
                      ? const Color(0xFFD8D8D8)
                      : colors.outline).withValues(alpha: 0.72),
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? colors.primary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class MoreActivitiesButton extends StatelessWidget {
  final bool enabled;
  final ActivityType selected;
  final ValueChanged<ActivityType> onSelected;

  const MoreActivitiesButton({
    super.key,
    required this.enabled,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isCustomSelected = selected != ActivityType.walk &&
        selected != ActivityType.run &&
        selected != ActivityType.cycle;

    return Expanded(
      child: InkWell(
        onTap: enabled
            ? () {
          // Show dialog with additional activity options
          showSmoothDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'More Activities',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(activityTypeIcon(ActivityType.walk), color: colors.onSurface),
                    title: const Text('Walking'),
                    trailing: selected == ActivityType.walk
                        ? Icon(Icons.check_rounded, color: colors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.walk);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(activityTypeIcon(ActivityType.run), color: colors.onSurface),
                    title: const Text('Running'),
                    trailing: selected == ActivityType.run
                        ? Icon(Icons.check_rounded, color: colors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.run);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(activityTypeIcon(ActivityType.cycle), color: colors.onSurface),
                    title: const Text('Cycling'),
                    trailing: selected == ActivityType.cycle
                        ? Icon(Icons.check_rounded, color: colors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.cycle);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(activityTypeIcon(ActivityType.trekking), color: colors.onSurface),
                    title: const Text('Trekking'),
                    trailing: selected == ActivityType.trekking
                        ? Icon(Icons.check_rounded, color: colors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.trekking);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(activityTypeIcon(ActivityType.climbing), color: colors.onSurface),
                    title: const Text('Climbing'),
                    trailing: selected == ActivityType.climbing
                        ? Icon(Icons.check_rounded, color: colors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.climbing);
                    },
                  ),
                ],
              ),
            ),
          );
        }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isCustomSelected
                ? colors.primary.withValues(alpha: 0.12)
                : (theme.brightness == Brightness.light
                    ? Colors.white.withValues(alpha: 0.72)
                    : colors.surface.withValues(alpha: 0.72)),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isCustomSelected
                  ? colors.primary
                  : (theme.brightness == Brightness.light
                      ? const Color(0xFFD8D8D8)
                      : colors.outline).withValues(alpha: 0.72),
              width: isCustomSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Icon(
              isCustomSelected ? activityTypeIcon(selected) : Icons.more_horiz_rounded,
              size: 22,
              color: isCustomSelected ? colors.primary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom control cluster: start button while idle, slide-to-unlock while
/// locked, and pause/resume/finish controls once unlocked.
class StartPauseControl extends StatelessWidget {
  final ActivityTrackingState state;
  final bool isLocked;
  final ValueChanged<bool> onLockToggle;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onSettingsTap;
  final VoidCallback? onMusicTap;

  const StartPauseControl({
    super.key,
    required this.state,
    required this.isLocked,
    required this.onLockToggle,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onSettingsTap,
    this.onMusicTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();
    final isIdle = state is TrackingIdle || state is TrackingCompleted;
    final isInProgress = state is TrackingInProgress;

    if (isIdle) {
      return Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: onMusicTap ?? () {
                showErrorSnackBar(context, 'Music integration is currently unavailable');
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.outline.withOpacity(0.5), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: colors.surface,
                padding: EdgeInsets.zero,
              ),
              child: Icon(Icons.music_note_rounded, color: colors.onSurface, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: customColors?.buttonText ?? Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          state.activityType.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_rounded, color: customColors?.buttonText ?? Colors.black, size: 22),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: onSettingsTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.outline.withOpacity(0.5), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: colors.surface,
                padding: EdgeInsets.zero,
              ),
              child: Icon(Icons.settings_rounded, color: colors.onSurface, size: 20),
            ),
          ),
        ],
      );
    }

    if (isLocked) {
      return SlidingButton(
        label: 'SLIDE TO UNLOCK',
        onTriggered: () => onLockToggle(false),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onStop,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.error, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: colors.surface,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: colors.error, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'FINISH',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: colors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 52,
          child: OutlinedButton(
            onPressed: () => onLockToggle(true),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.outline.withOpacity(0.5), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: colors.surface,
              padding: EdgeInsets.zero,
            ),
            child: Icon(Icons.lock_rounded, color: colors.onSurface, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 52,
            child: isInProgress
                ? OutlinedButton(
              onPressed: onPause,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: colors.surface,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_rounded, color: colors.primary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'PAUSE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            )
                : FilledButton(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: customColors?.buttonText ?? Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'RESUME',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: customColors?.buttonText ?? Colors.black, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slide-to-confirm control used to unlock the pause/finish controls while
/// tracking, preventing accidental taps.
class SlidingButton extends StatefulWidget {
  final String label;
  final VoidCallback onTriggered;

  const SlidingButton({
    super.key,
    required this.label,
    required this.onTriggered,
  });

  @override
  State<SlidingButton> createState() => _SlidingButtonState();
}

class _SlidingButtonState extends State<SlidingButton> {
  double _position = 0.0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDistance = constraints.maxWidth - 44 - 8;

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light ? const Color(0xFFF2F2F2) : colors.outline.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                left: _position,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_triggered) return;
                    setState(() {
                      _position = (_position + details.delta.dx).clamp(0.0, maxDistance);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_triggered) return;
                    if (_position >= maxDistance * 0.85) {
                      setState(() {
                        _position = maxDistance;
                        _triggered = true;
                      });
                      widget.onTriggered();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _position = 0.0;
                            _triggered = false;
                          });
                        }
                      });
                    } else {
                      setState(() {
                        _position = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: customColors?.buttonText ?? Colors.black,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}