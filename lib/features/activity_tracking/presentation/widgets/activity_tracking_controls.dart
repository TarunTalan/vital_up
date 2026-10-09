import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// Opaque control tile used for every button in the map overlay so they stay
/// legible over map tiles. [accent] switches to the selected / tinted style.
class _ControlTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  final bool filled;
  final double? width;

  const _ControlTile({
    required this.child,
    required this.onTap,
    this.accent,
    this.filled = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusButton);
    final Color background;
    if (filled) {
      background = accent ?? context.colors.primary;
    } else if (accent != null) {
      background = Color.alphaBlend(
        accent!.withValues(alpha: 0.13),
        v.surfaceElevated!,
      );
    } else {
      background = v.surfaceElevated!;
    }

    return SizedBox(
      width: width,
      height: AppDimens.buttonHeight,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: accent ?? v.glassBorder!,
                  width: accent != null
                      ? AppDimens.borderThick
                      : AppDimens.borderThin,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Icon + uppercase label content used inside the tracking control tiles.
class _ControlLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool iconTrailing;

  const _ControlLabel({
    required this.icon,
    required this.label,
    required this.color,
    this.iconTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: AppDimens.iconMd);
    final text = Text(
      label,
      maxLines: 1,
      style: context.text.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.space8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconTrailing
              ? [text, const SizedBox(width: AppDimens.space4), iconWidget]
              : [iconWidget, const SizedBox(width: AppDimens.space4), text],
        ),
      ),
    );
  }
}

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
        const SizedBox(width: AppDimens.space8),
        ActivityButton(
          icon: Icons.directions_run_rounded,
          selected: selected == ActivityType.run,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.run),
        ),
        const SizedBox(width: AppDimens.space8),
        ActivityButton(
          icon: Icons.directions_bike_rounded,
          selected: selected == ActivityType.cycle,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.cycle),
        ),
        const SizedBox(width: AppDimens.space8),
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
    final primary = context.colors.primary;
    return Expanded(
      child: _ControlTile(
        onTap: enabled ? onTap : null,
        accent: selected ? primary : null,
        child: Icon(
          icon,
          size: AppDimens.iconLg,
          color: selected ? primary : context.colors.onSurface,
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

  void _showOptions(BuildContext context) {
    final colors = context.colors;
    showSmoothDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('More Activities'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space8,
          vertical: AppDimens.space16,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in ActivityType.values)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  leading: Icon(
                    activityTypeIcon(type),
                    color: colors.onSurface,
                  ),
                  title: Text(type.label),
                  trailing: selected == type
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(type);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCustomSelected =
        selected != ActivityType.walk &&
        selected != ActivityType.run &&
        selected != ActivityType.cycle;

    return Expanded(
      child: _ControlTile(
        onTap: enabled ? () => _showOptions(context) : null,
        accent: isCustomSelected ? colors.primary : null,
        child: Icon(
          isCustomSelected
              ? activityTypeIcon(selected)
              : Icons.more_horiz_rounded,
          size: AppDimens.iconLg,
          color: isCustomSelected ? colors.primary : colors.onSurface,
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
    final colors = context.colors;
    final buttonText = context.vColors.buttonText!;
    final isIdle = state is TrackingIdle || state is TrackingCompleted;
    final isInProgress = state is TrackingInProgress;

    if (isIdle) {
      return Row(
        children: [
          _ControlTile(
            width: AppDimens.buttonHeight,
            onTap:
                onMusicTap ??
                () {
                  showErrorSnackBar(
                    context,
                    'Music is not available right now.',
                  );
                },
            child: Icon(
              Icons.music_note_rounded,
              color: colors.onSurface,
              size: AppDimens.iconMd,
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Expanded(
            child: _ControlTile(
              filled: true,
              onTap: onStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Start ${state.activityType.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge?.copyWith(
                          color: buttonText,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: buttonText,
                      size: AppDimens.iconLg,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          _ControlTile(
            width: AppDimens.buttonHeight,
            onTap: onSettingsTap,
            child: Icon(
              Icons.settings_rounded,
              color: colors.onSurface,
              size: AppDimens.iconMd,
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
          child: _ControlTile(
            onTap: onStop,
            accent: colors.error,
            child: _ControlLabel(
              icon: Icons.stop_rounded,
              label: 'FINISH',
              color: colors.error,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        _ControlTile(
          width: AppDimens.buttonHeight,
          onTap: () => onLockToggle(true),
          child: Icon(
            Icons.lock_rounded,
            color: colors.onSurface,
            size: AppDimens.iconMd,
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: isInProgress
              ? _ControlTile(
                  onTap: onPause,
                  accent: colors.primary,
                  child: _ControlLabel(
                    icon: Icons.pause_rounded,
                    label: 'PAUSE',
                    color: colors.primary,
                  ),
                )
              : _ControlTile(
                  filled: true,
                  onTap: onResume,
                  child: _ControlLabel(
                    icon: Icons.arrow_forward_rounded,
                    label: 'RESUME',
                    color: buttonText,
                    iconTrailing: true,
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

  static const double _knobSize = AppDimens.headerActionSize - AppDimens.space4;
  static const double _inset = AppDimens.space4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDistance =
            constraints.maxWidth - _knobSize - _inset * 2;

        return Container(
          height: AppDimens.buttonHeight,
          decoration: BoxDecoration(
            color: v.surfaceElevated,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(color: v.glassBorder!),
          ),
          padding: const EdgeInsets.symmetric(horizontal: _inset),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: _knobSize),
                child: Center(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _position,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_triggered) return;
                    setState(() {
                      _position = (_position + details.delta.dx).clamp(
                        0.0,
                        maxDistance,
                      );
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
                    width: _knobSize,
                    height: _knobSize,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.shadowY,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: v.buttonText,
                      size: AppDimens.iconLg,
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
