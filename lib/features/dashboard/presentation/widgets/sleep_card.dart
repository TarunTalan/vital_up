import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import '../../data/services/screen_time_service.dart';
import '../../data/services/sleep_service.dart';
import '../../domain/entities/sleep_session_info.dart';
import '../../domain/tracker_input_rules.dart';
import '../cubit/sleep_cubit.dart';
import '../cubit/sleep_state.dart';
import '../cubit/trend_cubit.dart';
import 'dashboard_card_header.dart';
import 'tracker_log_sheets.dart';

const _metric = TrackerMetric.sleep;

/// Colour for a 0–100 sleep score.
Color sleepScoreColor(int score) {
  if (score >= 85) return AppColors.success;
  if (score >= 70) return AppColors.teal;
  if (score >= 50) return AppColors.warning;
  return AppColors.error;
}

/// Home card: last night vs the nightly goal, bed / wake times, stages.
class SleepCard extends StatelessWidget {
  const SleepCard({super.key});

  Future<void> _refresh(BuildContext context) async {
    context.read<SleepCubit>().loadSleepData();
    await context.read<TrendCubit<SleepSessionInfo>>().load();
  }

  Future<void> _open(BuildContext context) async {
    await context.pushNamed(_metric.route);
    if (context.mounted) _refresh(context);
  }

  Future<void> _log(BuildContext context, {SleepSessionInfo? initial}) async {
    if (await showSleepLogSheet(context, initial: initial) && context.mounted) {
      _refresh(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SleepCubit, SleepState>(
      // A saved entry changes last night's bar.
      listenWhen: (_, state) =>
          state is SleepLoadedAuto || state is SleepLoadedManual,
      listener: (context, _) =>
          context.read<TrendCubit<SleepSessionInfo>>().load(),
      builder: (context, state) {
        final cubit = context.read<SleepCubit>();
        return switch (state) {
          SleepLoadedAuto(:final session) => _loaded(context, session, true),
          SleepLoadedManual(:final session) => _loaded(context, session, false),
          SleepNeedsConfirmation(:final estimate) => _confirm(
            context,
            cubit,
            estimate,
          ),
          SleepInBed(:final since) => _inBed(context, cubit, since),
          SleepNeedsManualEntry(:final canDetect) => TrackerCard(
            metric: _metric,
            status: TrackerStatus.notLogged,
            onOpen: () => _open(context),
            actions: [
              _logAction(context, filled: true),
              if (_isEvening) _bedtimeAction(context, cubit),
              if (!canDetect)
                TrackerQuickAction(
                  label: 'Auto-detect',
                  icon: Icons.auto_awesome_rounded,
                  color: _metric.color,
                  // The cubit re-checks when the user comes back.
                  onTap: sl<ScreenTimeService>().openSettings,
                ),
            ],
            child: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TrackerPrompt(
                    title: 'How did you sleep?',
                    message: canDetect
                        ? 'Log sleep to track your rest.'
                        : 'Log sleep, or allow usage access to detect it '
                              'from when your phone is idle.',
                    color: AppColors.trackSleep,
                  ),
                ],
              ),
            ),
          ),
          SleepNeedsHealthConnectInstall() => TrackerCard(
            metric: _metric,
            onOpen: () => _open(context),
            actions: [
              TrackerQuickAction(
                label: 'Install',
                icon: Icons.download_rounded,
                color: _metric.color,
                filled: true,
                onTap: cubit.installHealthConnect,
              ),
              _logAction(context),
            ],
            child: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  TrackerPrompt(
                    icon: Icons.health_and_safety_rounded,
                    title: 'Sync sleep',
                    message: 'Install Health Connect to sync your watch.',
                    color: AppColors.trackSleep,
                  ),
                ],
              ),
            ),
          ),
          SleepError() => TrackerCardPlaceholder(
            metric: _metric,
            onRetry: cubit.loadSleepData,
          ),
          _ => const TrackerCardPlaceholder(metric: _metric),
        };
      },
    );
  }

  /// Runs a one-tap sleep action and says so if it didn't save.
  static Future<void> _run(
    BuildContext context,
    Future<bool> Function() action, {
    String message = "Couldn't save your sleep. Try again.",
  }) async {
    if (!await action() && context.mounted) {
      showErrorSnackBar(context, message);
    }
  }

  /// "Going to bed" (Bedtime) is offered from 7 pm until 3 am.
  static bool get _isEvening {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 3;
  }

  Widget _bedtimeAction(BuildContext context, SleepCubit cubit) =>
      TrackerQuickAction(
        label: 'Bedtime',
        icon: Icons.bedtime_rounded,
        color: _metric.color,
        onTap: () => _run(
          context,
          cubit.goToBed,
          message: "Couldn't save your bedtime. Try again.",
        ),
      );

  /// After "Going to bed": cancel early on, then "I'm up" or adjust.
  Widget _inBed(BuildContext context, SleepCubit cubit, DateTime since) {
    final now = DateTime.now();
    final justNow = now.difference(since) < const Duration(hours: 1);
    final at = DateFormat.jm().format(since);
    return TrackerCard(
      metric: _metric,
      onOpen: () => _open(context),
      actions: justNow
          ? [
              TrackerQuickAction(
                label: 'Cancel',
                icon: Icons.close_rounded,
                color: _metric.color,
                onTap: () => _run(
                  context,
                  cubit.cancelBedtime,
                  message: "Couldn't cancel your bedtime. Try again.",
                ),
              ),
            ]
          : [
              TrackerQuickAction(
                label: "I'm up",
                icon: Icons.wb_sunny_rounded,
                color: _metric.color,
                filled: true,
                onTap: () => _run(context, cubit.wakeUp),
              ),
              TrackerQuickAction(
                label: 'Adjust',
                icon: Icons.edit_rounded,
                color: _metric.color,
                onTap: () => _log(
                  context,
                  initial: SleepSessionInfo(
                    bedTime: since,
                    wakeTime: now,
                    duration: now.difference(since),
                    source: SleepDataSource.manual,
                  ),
                ),
              ),
            ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TrackerPrompt(
              icon: Icons.bedtime_rounded,
              title: justNow ? 'Sleep well' : 'Good morning',
              message: justNow
                  ? 'In bed since $at.'
                  : "In bed since $at. Tap I'm up to save the night.",
              color: AppColors.trackSleep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _logAction(BuildContext context, {bool filled = false}) =>
      TrackerQuickAction(
        label: _metric.logLabel,
        icon: _metric.logIcon,
        color: _metric.color,
        filled: filled,
        onTap: () => _log(context),
      );

  /// Last night as estimated from screen-off time: confirm or adjust.
  Widget _confirm(
    BuildContext context,
    SleepCubit cubit,
    SleepSessionInfo estimate,
  ) {
    final time = DateFormat.jm();
    return TrackerCard(
      metric: _metric,
      status: TrackerStatus.notLogged,
      onOpen: () => _open(context),
      actions: [
        TrackerQuickAction(
          label: 'Confirm',
          icon: Icons.check_rounded,
          color: _metric.color,
          filled: true,
          onTap: () => _run(context, cubit.confirmEstimate),
        ),
        TrackerQuickAction(
          label: 'Adjust',
          icon: Icons.edit_rounded,
          color: _metric.color,
          onTap: () => _log(context, initial: estimate),
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TrackerPrompt(
              icon: Icons.smartphone_rounded,
              title: 'Slept ${formatDashboardDuration(estimate.duration)}?',
              message:
                  '${time.format(estimate.bedTime)} – '
                  '${time.format(estimate.wakeTime)}, '
                  'from when your phone was idle.',
              color: AppColors.trackSleep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _loaded(BuildContext context, SleepSessionInfo session, bool isAuto) {
    final goalMinutes = sl<SleepService>().getGoalMinutes();
    final minutes = session.duration.inMinutes;
    return TrackerCard(
      metric: _metric,
      status: TrackerStatus.of(
        value: minutes.toDouble(),
        goal: goalMinutes.toDouble(),
        paceFraction: 1,
      ),
      onOpen: () => _open(context),
      actions: [
        _logAction(context),
        if (_isEvening) _bedtimeAction(context, context.read<SleepCubit>()),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TrackerProgress(
              value: formatDashboardDuration(session.duration),
              goal: formatDashboardDuration(Duration(minutes: goalMinutes)),
              fraction: safeFraction(minutes, goalMinutes),
              color: _metric.color,
              caption: 'Score ${session.sleepScore} · ${session.scoreCategory}',
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep / REM / light / awake split of one night.
class SleepStagesBar extends StatelessWidget {
  final SleepSessionInfo session;

  const SleepStagesBar({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Deep', session.deepSleepMinutes ?? 0, AppColors.sleepDeep),
      ('REM', session.remSleepMinutes ?? 0, AppColors.sleepRem),
      ('Light', session.lightSleepMinutes ?? 0, AppColors.teal),
      ('Awake', session.awakeMinutes ?? 0, AppColors.warning),
    ].where((s) => s.$2 > 0).toList();
    if (stages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: SizedBox(
            height: AppDimens.stageBarHeight,
            child: Row(
              children: [
                for (final s in stages)
                  Expanded(
                    flex: s.$2,
                    child: ColoredBox(color: s.$3),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        Wrap(
          spacing: AppDimens.space12,
          runSpacing: AppDimens.space4,
          children: [
            for (final s in stages)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppDimens.legendDot,
                    height: AppDimens.legendDot,
                    decoration: BoxDecoration(
                      color: s.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppDimens.space4),
                  Text(
                    '${s.$1} ${formatDashboardDuration(Duration(minutes: s.$2))}',
                    style: context.text.labelSmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
