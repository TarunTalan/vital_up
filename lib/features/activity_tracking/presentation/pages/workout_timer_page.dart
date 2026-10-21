import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vital_up/core/permissions/permission_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_target_result.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_target_rules.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/workout_timer_cubit.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_common_widgets.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_controls.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_completion_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_settings_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_stats.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/countdown_overlay.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/hr_device_sheet.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/workout_music.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/log_workout_sheet.dart';

/// Shows the workout being timed (the tray notification). An activity
/// screen already open is brought back to the top instead of stacking a
/// second copy (with a timer running it shows the timer), so Back returns
/// to where the user came from.
void openWorkoutTimer(BuildContext context) {
  const name = 'workout-timer';
  const screens = {name, 'activity-tracking'};
  final router = GoRouter.of(context);
  final matches = router.routerDelegate.currentConfiguration.matches;
  final open = matches.reversed
      .where(
        (m) =>
            m.route is GoRoute && screens.contains((m.route as GoRoute).name),
      )
      .firstOrNull;
  if (open == null) {
    router.pushNamed(name);
    return;
  }
  // Pages, sheets and dialogs above it close (a sheet returns null).
  Navigator.of(context, rootNavigator: true).popUntil((route) {
    final settings = route.settings;
    return route.isFirst || (settings is Page && settings.key == open.pageKey);
  });
}

/// Times a workout without a route (gym, yoga, a match). No map and no GPS:
/// the timer runs off the clock, so closing the app doesn't stop it, and
/// neither does leaving this screen: Back (or the down arrow) leaves it
/// running, with the tray notification and Home's `ActiveWorkoutBar` to
/// come back. Its controls start locked (slide to unlock) so a pocket tap
/// can't pause or finish it. Opening this page again shows the workout
/// being timed.
class WorkoutTimerPage extends StatelessWidget {
  /// Type to start with; ignored while a workout is already being timed.
  final ActivityType type;

  /// An outdoor type was picked: the activity screen shows the GPS view.
  final ValueChanged<ActivityType>? onOutdoorSelected;

  const WorkoutTimerPage({
    super.key,
    this.type = ActivityType.strength,
    this.onOutdoorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WorkoutTimerCubit>(param1: type),
      child: _ReloadOnResume(
        child: _WorkoutTimerView(onOutdoorSelected: onOutdoorSelected),
      ),
    );
  }
}

/// Pause / Resume tapped on the notification while the app was in the
/// background ran in another isolate: re-read the timer on return.
class _ReloadOnResume extends StatefulWidget {
  final Widget child;

  const _ReloadOnResume({required this.child});

  @override
  State<_ReloadOnResume> createState() => _ReloadOnResumeState();
}

class _ReloadOnResumeState extends State<_ReloadOnResume> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) context.read<WorkoutTimerCubit>().reload();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WorkoutTimerView extends StatefulWidget {
  final ValueChanged<ActivityType>? onOutdoorSelected;

  const _WorkoutTimerView({this.onOutdoorSelected});

  @override
  State<_WorkoutTimerView> createState() => _WorkoutTimerViewState();
}

class _WorkoutTimerViewState extends State<_WorkoutTimerView> {
  /// Pause / Finish need a slide first while a workout is timed.
  bool _locked = true;

  final _prefs = WorkoutPrefsNotifier();
  final _units = DistanceUnitNotifier();
  final _heartRate = HeartRateManager();
  StreamSubscription<int?>? _bpmSubscription;
  int? _bpm;

  /// The state before the change [_onTimerChanged] is told about.
  WorkoutTimerState? _before;

  /// The 3-2-1 before a workout starts, as on the GPS screen.
  bool _countingDown = false;

  /// A workout is being timed: leaving keeps it (and its music) going.
  bool _timing = false;

  late final WorkoutMusic _music = WorkoutMusic(
    _prefs,
    onError: (message) {
      if (mounted) showErrorSnackBar(context, message);
    },
  );

  @override
  void initState() {
    super.initState();
    _units.load();
    _prefs.load().then((_) => _music.refreshFavorite());
    _loadGoalTarget();
    sl<VoiceCoachService>().init();
    _bpmSubscription = _heartRate.bpmStream.listen((bpm) {
      if (mounted) setState(() => _bpm = bpm);
    });
  }

  @override
  void dispose() {
    // Music is for this workout only, as on the GPS screen; left running,
    // the workout keeps it (the timer's end here stops it).
    if (!_timing) {
      _prefs.setBackgroundAudioTrack('None');
      _music.stop();
    }
    _music.dispose();
    sl<VoiceCoachService>().stop();
    _bpmSubscription?.cancel();
    _heartRate.dispose();
    _units.dispose();
    _prefs.dispose();
    super.dispose();
  }

  /// What's left of today's active-minutes (else calories) goal: the
  /// target of a workout started without one set by hand.
  ({WorkoutTargetType type, double value})? _goalTarget;

  Future<void> _loadGoalTarget() async {
    try {
      final snapshot = await sl<ActivityGoalsRepository>().getProgress(
        TrendRange.week,
      );
      if (mounted) _goalTarget = timerTargetFromGoals(snapshot.goals);
    } catch (e) {
      debugPrint('Reading activity goals failed: $e');
    }
  }

  /// The target set in settings, or null.
  ({WorkoutTargetType type, double value})? get _target {
    final p = _prefs.value;
    return p.timerTargetType == WorkoutTargetType.none
        ? null
        : (type: p.timerTargetType, value: p.timerTargetValue);
  }

  /// The first Start offers notifications with the card (the timer and its
  /// Pause / Resume in the tray), before any countdown; the timer starts
  /// either way.
  Future<void> _offerNotifications() => ensurePermission(
    context,
    const PermissionAsk(
      main: AppPermission.notifications,
      title: 'Your timer, always at hand',
      message:
          'See the time and pause or resume from your notifications, '
          'even with VitalUp closed.',
      onceKey: 'workout_timer',
    ),
  );

  /// Starts the timer; today's goal becomes the target unless one is set.
  void _start(WorkoutTimerCubit cubit) {
    final goal = _goalTarget;
    if (goal != null && _target == null) {
      _prefs.setTimerTarget(goal.type, goal.value);
    }
    cubit.start();
  }

  /// Music follows the timer, whichever way it changed (these controls or
  /// the notification's Pause / Resume).
  void _onTimerChanged(WorkoutTimerState before, WorkoutTimerState after) {
    if (!after.isStarted) {
      _music.stop();
    } else if (!before.isStarted) {
      _music.play();
    } else if (after.isRunning) {
      _music.resume();
    } else {
      _music.pause();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivitySettingsPage(
          unitNotifier: _units,
          prefsNotifier: _prefs,
          hrManager: _heartRate,
          liveHeartRate: _bpm,
          activityType: context.read<WorkoutTimerCubit>().state.type,
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    final cubit = context.read<WorkoutTimerCubit>();
    // Stop the clock while the user picks the intensity.
    await cubit.pause();
    if (!context.mounted) return;
    final intensity = await showAppBottomSheet<WorkoutIntensity>(
      context: context,
      builder: (_) => _FinishSheet(state: cubit.state),
    );
    if (intensity == null || !context.mounted) return;
    final outcome = await cubit.finish(intensity, target: _target);
    if (outcome == WorkoutSaveOutcome.saved) _prefs.clearTimerTarget();
    if (!context.mounted) return;
    switch (outcome) {
      case WorkoutSaveOutcome.saved:
        // The same result screen as a GPS workout; back on it returns here.
        final session = cubit.lastSaved;
        if (session == null) {
          showSuccessSnackBar(context, 'Workout saved');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (resultContext) => ActivityCompletionPage(
              session: session,
              onBack: () => Navigator.of(resultContext).pop(),
              onNewActivity: () => Navigator.of(resultContext).pop(),
              onViewHistory: () => resultContext.pushNamed('activity-history'),
            ),
          ),
        );
      case WorkoutSaveOutcome.tooShort:
        await _tooShort(context);
      case WorkoutSaveOutcome.failed:
        showErrorSnackBar(context, "Couldn't save your workout. Try again.");
    }
  }

  Future<void> _tooShort(BuildContext context) async {
    final discard = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Too short to save'),
        content: const Text("Workouts under a minute aren't saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final cubit = context.read<WorkoutTimerCubit>();
    if (discard == true) {
      await cubit.discard();
      await _prefs.clearTimerTarget();
    } else {
      await cubit.resume();
    }
  }

  Future<void> _discard(BuildContext context) async {
    final colors = context.colors;
    final confirmed = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this workout?'),
        content: const Text("The time so far won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<WorkoutTimerCubit>().discard();
      await _prefs.clearTimerTarget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutTimerCubit, WorkoutTimerState>(
      listenWhen: (before, after) {
        _before = before;
        return before.isStarted != after.isStarted ||
            before.isRunning != after.isRunning;
      },
      listener: (context, after) => _onTimerChanged(_before ?? after, after),
      builder: (context, state) {
        final cubit = context.read<WorkoutTimerCubit>();
        final locked = _locked && state.isStarted;
        _timing = state.isStarted;
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && state.isStarted) {
              showSuccessSnackBar(
                context,
                'Your ${state.type.label.toLowerCase()} timer keeps running',
              );
            }
          },
          child: Stack(
            children: [
              AppScaffold(
                // The GPS view's top: back and history while idle; during
                // a workout, a down arrow that leaves it running.
                header: SafeArea(
                  bottom: false,
                  child: state.isStarted
                      ? Padding(
                          padding: EdgeInsets.all(context.gutter),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: RoundIconButton(
                              icon: Icons.keyboard_arrow_down_rounded,
                              tooltip: 'Leave it running',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.all(context.gutter),
                          child: Row(
                            children: [
                              RoundIconButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const Spacer(),
                              RoundIconButton(
                                icon: Icons.history_rounded,
                                tooltip: 'History',
                                onPressed: () =>
                                    context.pushNamed('activity-history'),
                              ),
                            ],
                          ),
                        ),
                ),
                // AppScaffold pads it to the gutter. Hidden during the
                // countdown, as on the GPS screen.
                bottomBar: _countingDown
                    ? null
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WorkoutMusicBar(music: _music),
                          if (!state.isStarted) ...[
                            ActivitySelector(
                              selected: state.type,
                              enabled: !_countingDown,
                              // The GPS view's tiles: an outdoor type switches to it.
                              onSelected: (type) {
                                if (type.isGpsBased) {
                                  widget.onOutdoorSelected?.call(type);
                                } else {
                                  cubit.selectType(type);
                                }
                              },
                            ),
                            const SizedBox(height: AppDimens.space8),
                          ],
                          StartPauseControl(
                            isIdle: !state.isStarted,
                            isRunning: state.isRunning,
                            startLabel: 'Start ${state.type.label}',
                            canResume: !state.reachedLimit,
                            isLocked: locked,
                            onLockToggle: (value) =>
                                setState(() => _locked = value),
                            onStart: () async {
                              HapticFeedback.mediumImpact();
                              await _offerNotifications();
                              if (!mounted || cubit.state.isStarted) return;
                              setState(() => _locked = true);
                              if (_prefs.value.countdownDurationSeconds > 0) {
                                setState(() => _countingDown = true);
                              } else {
                                _start(cubit);
                              }
                            },
                            onPause: cubit.pause,
                            onResume: cubit.resume,
                            onStop: () => _finish(context),
                            onSettingsTap: _openSettings,
                            onMusicTap: () => _music.openPicker(context),
                          ),
                        ],
                      ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<WorkoutPrefs>(
                      valueListenable: _prefs,
                      builder: (context, _, _) => _TimerCard(
                        state: state,
                        heartRate: _bpm,
                        target: _target,
                      ),
                    ),
                    const SizedBox(height: AppDimens.sectionGap),
                    if (state.isStarted) ...[
                      const AppInfoNote(
                        message: 'The timer keeps going if you close the app.',
                      ),
                      if (!state.isRunning && !locked) ...[
                        const SizedBox(height: AppDimens.space8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _discard(context),
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.error,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Discard workout'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (_countingDown)
                Positioned.fill(
                  child: CountdownOverlay(
                    durationSeconds: _prefs.value.countdownDurationSeconds,
                    voiceCoachEnabled: _prefs.value.voiceCoachEnabled,
                    onFinished: () {
                      if (!mounted) return;
                      setState(() => _countingDown = false);
                      _start(cubit);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The same card as on the GPS screen: the time, then the workout's own
/// figures (calories so far, heart rate with a strap connected).
class _TimerCard extends StatelessWidget {
  final WorkoutTimerState state;
  final int? heartRate;
  final ({WorkoutTargetType type, double value})? target;

  const _TimerCard({required this.state, this.heartRate, this.target});

  /// Share of the target done, 0-1.
  double _progress(({WorkoutTargetType type, double value}) target) {
    final done = target.type == WorkoutTargetType.duration
        ? state.elapsed.inSeconds / 60
        : state.caloriesSoFar.toDouble();
    return (done / target.value).clamp(0.0, 1.0);
  }

  String get _status {
    if (!state.isStarted) return 'Ready';
    if (state.reachedLimit) return 'Stopped at 6 hours';
    return state.isRunning ? 'Timing' : 'Paused';
  }

  @override
  Widget build(BuildContext context) {
    final bpm = heartRate;
    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        children: [
          FitText(
            formatDuration(state.elapsed),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppTextStyles.metricLarge.copyWith(
              color: context.colors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          AppCaption(_status),
          const SizedBox(height: AppDimens.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatColumn(value: state.type.label, label: 'ACTIVITY'),
              ),
              Expanded(
                child: StatColumn(
                  value: '${state.caloriesSoFar}',
                  label: 'CALORIES',
                ),
              ),
              if (bpm != null)
                Expanded(
                  child: StatColumn(value: '$bpm', label: 'HEART RATE'),
                ),
            ],
          ),
          if (target case final target?) ...[
            const SizedBox(height: AppDimens.space12),
            Builder(
              builder: (context) {
                final v = context.vColors;
                final progress = _progress(target);
                return Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: AppDimens.iconXs,
                      color: v.grayText,
                    ),
                    const SizedBox(width: AppDimens.space4),
                    Expanded(
                      child: AppProgressBar(
                        value: progress,
                        color: progress >= 1.0
                            ? v.success
                            : context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: AppDimens.space8),
                    Text(
                      formatActivityTarget(target.type.name, target.value),
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Picks how hard the workout was; pops with the [WorkoutIntensity].
class _FinishSheet extends StatefulWidget {
  final WorkoutTimerState state;

  const _FinishSheet({required this.state});

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  WorkoutIntensity _intensity = WorkoutIntensity.moderate;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return TrackerSheet(
      metric: TrackerMetric.activity,
      title: 'Finish workout',
      subtitle: '${state.type.label} · ${formatDuration(state.elapsed)}',
      action: AppPrimaryButton(
        label: 'Save workout',
        onTap: () => Navigator.pop(context, _intensity),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppCaption('How hard was it?'),
          const SizedBox(height: AppDimens.space8),
          WorkoutIntensityPicker(
            selected: _intensity,
            onChanged: (value) => setState(() => _intensity = value),
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            _intensity.hint,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}
