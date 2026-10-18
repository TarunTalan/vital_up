
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/workout_timer_cubit.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/log_workout_sheet.dart';

/// Shows the timer screen for the workout being timed (the tray
/// notification, the tracking page). One already open is brought back to
/// the top instead of stacking a second copy, so Back returns to where the
/// user came from rather than to another timer.
void openWorkoutTimer(BuildContext context) {
  const name = 'workout-timer';
  final router = GoRouter.of(context);
  final matches = router.routerDelegate.currentConfiguration.matches;
  final open = matches.reversed
      .where((m) => m.route is GoRoute && (m.route as GoRoute).name == name)
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
/// the timer runs off the clock, so leaving the screen or closing the app
/// doesn't stop it. Opening this page again shows the workout being timed.
class WorkoutTimerPage extends StatelessWidget {
  /// Type to start with; ignored while a workout is already being timed.
  final ActivityType type;

  const WorkoutTimerPage({super.key, this.type = ActivityType.strength});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WorkoutTimerCubit>(param1: type),
      child: const _ReloadOnResume(child: _WorkoutTimerView()),
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

class _WorkoutTimerView extends StatelessWidget {
  const _WorkoutTimerView();

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
    final outcome = await cubit.finish(intensity);
    if (!context.mounted) return;
    switch (outcome) {
      case WorkoutSaveOutcome.saved:
        showSuccessSnackBar(context, 'Workout saved');
        context.pop();
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
    }
  }

  Future<void> _logPast(BuildContext context) async {
    final type = context.read<WorkoutTimerCubit>().state.type;
    final saved = await showLogWorkoutSheet(context, initialType: type);
    if (saved && context.mounted) {
      showSuccessSnackBar(context, 'Workout saved');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutTimerCubit, WorkoutTimerState>(
      builder: (context, state) {
        final cubit = context.read<WorkoutTimerCubit>();
        return AppScaffold(
          header: const AppPageHeader(title: 'Workout'),
          bottomBar: _Controls(
            state: state,
            onStart: () {
              HapticFeedback.mediumImpact();
              cubit.start();
            },
            onPause: cubit.pause,
            onResume: cubit.resume,
            onFinish: () => _finish(context),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimens.space16),
              _TimerCard(state: state),
              const SizedBox(height: AppDimens.sectionGap),
              if (!state.isStarted) ...[
                const AppCaption('Workout'),
                const SizedBox(height: AppDimens.space8),
                WorkoutTypePicker(
                  selected: state.type,
                  onSelected: cubit.selectType,
                ),
                const SizedBox(height: AppDimens.sectionGap),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _logPast(context),
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Log a past workout instead'),
                  ),
                ),
              ] else ...[
                const AppInfoNote(
                  message:
                      'The timer keeps going if you leave this screen or '
                      'close the app.',
                ),
                if (!state.isRunning) ...[
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
        );
      },
    );
  }
}

class _TimerCard extends StatelessWidget {
  final WorkoutTimerState state;

  const _TimerCard({required this.state});

  String get _status {
    if (!state.isStarted) return 'Ready';
    if (state.reachedLimit) return 'Stopped at 6 hours';
    return state.isRunning ? 'Timing' : 'Paused';
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return AppCard(
      child: Column(
        children: [
          AppIconBadge(
            icon: Icon(activityTypeIcon(state.type)),
            size: AppDimens.iconBadgeLarge,
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            state.type.label,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          FitText(
            formatDuration(state.elapsed),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppTextStyles.metricLarge.copyWith(
              color: context.colors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: v.grayText),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final WorkoutTimerState state;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  const _Controls({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (!state.isStarted) {
      content = AppPrimaryButton(label: 'Start', onTap: onStart);
    } else {
      final secondary = state.isRunning
          ? AppSecondaryButton(label: 'Pause', onTap: onPause)
          : AppSecondaryButton(
              label: 'Resume',
              enabled: !state.reachedLimit,
              onTap: onResume,
            );
      content = Row(
        children: [
          Expanded(child: secondary),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: AppPrimaryButton(
              label: 'Finish',
              isLoading: state.saving,
              onTap: onFinish,
            ),
          ),
        ],
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space12,
          context.gutter,
          AppDimens.space16,
        ),
        child: content,
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
