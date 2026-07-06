import 'package:flutter/material.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';

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
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFE3E3E3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(icon, size: 22, color: Colors.black),
        ),
      ),
    );
  }
}

class MoreActivitiesButton extends StatelessWidget {
  final bool enabled;
  final ValueChanged<ActivityType> onSelected;

  const MoreActivitiesButton({
    super.key,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: enabled
            ? () {
          // Show dialog with additional activity options
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('More Activities'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.directions_walk_rounded),
                    title: const Text('Walking'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.walk);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_run_rounded),
                    title: const Text('Running'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.run);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_bike_rounded),
                    title: const Text('Cycling'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.cycle);
                    },
                  ),
                ],
              ),
            ),
          );
        }
            : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFE3E3E3),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(Icons.more_horiz_rounded, size: 22, color: Colors.black),
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
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = state is TrackingIdle || state is TrackingCompleted;
    final isInProgress = state is TrackingInProgress;

    if (isIdle) {
      return Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Music integration coming soon')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1),
                shape: const RoundedRectangleBorder(),
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          state.activityType.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 22),
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
                side: const BorderSide(color: Colors.black, width: 1),
                shape: const RoundedRectangleBorder(),
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.settings_rounded, color: Colors.black, size: 20),
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
                side: const BorderSide(color: Colors.black, width: 2),
                shape: const RoundedRectangleBorder(),
                backgroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.black, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'FINISH',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
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
              side: const BorderSide(color: Colors.black, width: 1),
              shape: const RoundedRectangleBorder(),
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.black, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 52,
            child: isInProgress
                ? FilledButton(
              onPressed: onPause,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_rounded, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'PAUSE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
                : FilledButton(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RESUME',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDistance = constraints.maxWidth - 46 - 8;

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
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
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black,
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