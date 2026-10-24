import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_recovery_service.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_timer_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// What the bar shows: a timed workout, or a GPS workout the app was
/// closed during (its page offers Resume / Save / Discard).
sealed class ActiveWorkout {
  const ActiveWorkout();
}

class TimedWorkout extends ActiveWorkout {
  final WorkoutTimer timer;
  const TimedWorkout(this.timer);
}

class InterruptedGpsWorkout extends ActiveWorkout {
  const InterruptedGpsWorkout();
}

/// Above the bottom navigation while a workout is under way, on every tab:
/// the type and live time (or Paused), opening the workout on tap. Hidden
/// otherwise. Follows the timer store (including the notification's Pause
/// / Resume) and re-reads on return to the app and once a second.
class ActiveWorkoutBar extends StatefulWidget {
  /// For tests: what to show instead of reading the stores.
  final ActiveWorkout? Function()? read;
  final DateTime Function() clock;

  const ActiveWorkoutBar({super.key, this.read, this.clock = DateTime.now});

  /// The timer first (it's running now); else a GPS checkpoint left by a
  /// workout the app was closed during.
  static ActiveWorkout? readStores() {
    if (!sl.isRegistered<SharedPreferences>()) return null;
    final prefs = sl<SharedPreferences>();
    final timer = WorkoutTimerStore(prefs).read();
    if (timer != null) return TimedWorkout(timer);
    if (WorkoutCheckpointStore(prefs).read() != null) {
      return const InterruptedGpsWorkout();
    }
    return null;
  }

  @override
  State<ActiveWorkoutBar> createState() => _ActiveWorkoutBarState();
}

class _ActiveWorkoutBarState extends State<ActiveWorkoutBar> {
  ActiveWorkout? _workout;
  Timer? _ticker;
  StreamSubscription<void>? _changes;
  AppLifecycleListener? _lifecycle;

  ActiveWorkout? _read() => (widget.read ?? ActiveWorkoutBar.readStores).call();

  @override
  void initState() {
    super.initState();
    _workout = _read();
    if (widget.read == null && sl.isRegistered<SharedPreferences>()) {
      _changes = WorkoutTimerStore(
        sl<SharedPreferences>(),
      ).changes.listen((_) => _refresh());
    }
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    // Ticks the clock, and notices a workout started or finished on a
    // page above Home (no store stream for GPS checkpoints).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    final next = _read();
    final running = next is TimedWorkout && next.timer.isRunning;
    // Rebuild only when something shows changes: every second while the
    // clock runs, otherwise when the workout comes or goes.
    if (running || !_same(next, _workout)) setState(() => _workout = next);
  }

  static bool _same(ActiveWorkout? a, ActiveWorkout? b) => switch ((a, b)) {
    (null, null) => true,
    (InterruptedGpsWorkout(), InterruptedGpsWorkout()) => true,
    (TimedWorkout(timer: final x), TimedWorkout(timer: final y)) =>
      x.encode() == y.encode(),
    _ => false,
  };

  @override
  void dispose() {
    _ticker?.cancel();
    _changes?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _open(ActiveWorkout workout) {
    switch (workout) {
      case TimedWorkout():
        openWorkoutTimer(context);
      case InterruptedGpsWorkout():
        context.pushNamed('activity-tracking');
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    return AnimatedSwitcher(
      duration: AppDurations.medium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: workout == null
          ? const SizedBox(key: ValueKey('none'), width: double.infinity)
          : _bar(context, workout),
    );
  }

  Widget _bar(BuildContext context, ActiveWorkout workout) {
    final color = TrackerMetric.activity.color;
    final grey = context.vColors.grayText;
    final (
      IconData icon,
      String title,
      String status,
      String? time,
      bool live,
    ) = switch (workout) {
      TimedWorkout(:final timer) => (
        activityTypeIcon(timer.type),
        timer.type.label,
        timer.isRunning ? 'In progress' : 'Paused',
        formatDuration(timer.elapsed(widget.clock())),
        timer.isRunning,
      ),
      InterruptedGpsWorkout() => (
        Icons.directions_run_rounded,
        'Workout stopped',
        'Tap to resume or save it',
        null,
        false,
      ),
    };
    return Padding(
      key: ValueKey(workout.runtimeType),
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        AppDimens.space8,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
        child: Semantics(
          button: true,
          label: [title, status, ?time].join(', '),
          excludeSemantics: true,
          child: Material(
            color: context.vColors.navBg,
            borderRadius: BorderRadius.circular(AppDimens.radiusNavBar),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusNavBar),
              onTap: () => _open(workout),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusNavBar),
                  boxShadow: AppShadows.elevated,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space12,
                    vertical: AppDimens.space8,
                  ),
                  child: Row(
                    children: [
                      _LiveBadge(icon: icon, color: color, live: live),
                      const SizedBox(width: AppDimens.space12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FitText(title, style: context.text.titleSmall),
                            FitText(
                              status,
                              style: context.text.bodySmall?.copyWith(
                                color: grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: AppDimens.space8),
                        Text(
                          time,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                      const SizedBox(width: AppDimens.space4),
                      const AppChevron(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The activity's icon in a tinted circle; a soft ring breathes around it
/// while the clock runs (none with reduced motion).
class _LiveBadge extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool live;

  const _LiveBadge({
    required this.icon,
    required this.color,
    required this.live,
  });

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.slow * 4,
  );

  void _sync() {
    final animate = widget.live && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = AppIconBadge(
      size: AppDimens.iconBadgeSmall,
      color: widget.color,
      icon: Icon(
        widget.icon,
        size: AppDimens.iconXs,
        color: AppIconBadge.glyphColor(context, widget.color),
      ),
    );
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (_pulse.value > 0)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 * _pulse.value),
                blurRadius: AppDimens.space8 * _pulse.value,
                spreadRadius: AppDimens.space2 * _pulse.value,
              ),
          ],
        ),
        child: child,
      ),
      child: badge,
    );
  }
}
