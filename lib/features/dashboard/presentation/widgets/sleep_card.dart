import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
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
          SleepLoadedAuto(:final session) => _loaded(context, cubit, session),
          SleepLoadedManual(:final session) => _loaded(context, cubit, session),
          SleepNeedsConfirmation(:final estimate) => _confirm(
            context,
            cubit,
            estimate,
          ),
          SleepInBed(:final since) => _inBed(context, cubit, since),
          SleepNeedsManualEntry(:final canDetect) => _prompt(
            context,
            title: 'How did you sleep?',
            action: _logAction(
              context,
              cubit,
              offerAutoDetect: !canDetect,
              filled: true,
            ),
          ),
          SleepNeedsHealthConnectInstall() => _prompt(
            context,
            title: 'How did you sleep?',
            action: _logAction(
              context,
              cubit,
              offerHealthConnect: true,
              filled: true,
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

  /// "Going to bed" is offered from 7 pm until 3 am.
  static bool get _isEvening {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 3;
  }

  /// Card with one centred title and a single action. Every state keeps to
  /// one button so the half-width tile never squeezes labels; other
  /// choices live in [_showChoices].
  Widget _prompt(
    BuildContext context, {
    required String title,
    required Widget action,
    TrackerStatus? status = TrackerStatus.notLogged,
  }) {
    return TrackerCard(
      metric: _metric,
      status: status,
      onOpen: () => _open(context),
      actions: [action],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [TrackerPrompt(title: title, color: _metric.color)],
      ),
    );
  }

  /// "Log sleep": straight to the log sheet when that's the only choice,
  /// otherwise a sheet listing the ways to record the night.
  Widget _logAction(
    BuildContext context,
    SleepCubit cubit, {
    bool offerAutoDetect = false,
    bool offerHealthConnect = false,
    bool filled = false,
  }) {
    return TrackerQuickAction(
      label: _metric.logLabel,
      icon: _metric.logIcon,
      svgAsset: _metric.logIconAsset,
      color: _metric.color,
      filled: filled,
      onTap: () async {
        final evening = _isEvening;
        if (!evening && !offerAutoDetect && !offerHealthConnect) {
          return _log(context);
        }
        final choice = await _showChoices(
          context,
          title: 'Log sleep',
          options: [
            const _SleepOption(
              _SleepChoice.enterTimes,
              Icons.edit_calendar_rounded,
              'Enter sleep times',
              'Set when you went to bed and woke up',
            ),
            if (evening)
              const _SleepOption(
                _SleepChoice.goToBed,
                Icons.bedtime_rounded,
                'Going to bed now',
                "Tap I'm up in the morning to save the night",
              ),
            if (offerAutoDetect)
              const _SleepOption(
                _SleepChoice.autoDetect,
                Icons.auto_awesome_rounded,
                'Turn on auto-detect',
                'Estimate sleep from when your phone is idle',
              ),
            if (offerHealthConnect)
              const _SleepOption(
                _SleepChoice.healthConnect,
                Icons.health_and_safety_rounded,
                'Sync with Health Connect',
                'Bring in sleep from your watch or other apps',
              ),
          ],
        );
        if (!context.mounted) return;
        switch (choice) {
          case _SleepChoice.enterTimes:
            await _log(context);
          case _SleepChoice.goToBed:
            await _run(
              context,
              cubit.goToBed,
              message: "Couldn't save your bedtime. Try again.",
            );
          case _SleepChoice.autoDetect:
            // The cubit re-checks when the user comes back.
            await sl<ScreenTimeService>().openSettings();
          case _SleepChoice.healthConnect:
            await cubit.installHealthConnect();
          case _SleepChoice.confirm || null:
        }
      },
    );
  }

  /// After "Going to bed": cancel early on, then "I'm up" or adjust.
  Widget _inBed(BuildContext context, SleepCubit cubit, DateTime since) {
    if (DateTime.now().difference(since) < const Duration(hours: 1)) {
      return _prompt(
        context,
        title: 'Sleep well',
        status: null,
        action: TrackerQuickAction(
          label: 'Cancel',
          icon: Icons.close_rounded,
          color: _metric.color,
          onTap: () => _run(
            context,
            cubit.cancelBedtime,
            message: "Couldn't cancel your bedtime. Try again.",
          ),
        ),
      );
    }
    // "Good morning" only in the morning; in bed late at night it says
    // since when instead.
    final hour = DateTime.now().hour;
    final greeting = hour >= 4 && hour < 12
        ? 'Good morning'
        : 'In bed since ${DateFormat.jm().format(since)}';
    return _prompt(
      context,
      title: greeting,
      status: null,
      action: TrackerQuickAction(
        label: "I'm up",
        icon: Icons.wb_sunny_rounded,
        color: _metric.color,
        filled: true,
        onTap: () async {
          final choice = await _showChoices(
            context,
            title: greeting,
            subtitle: 'In bed since ${DateFormat.jm().format(since)}',
            options: const [
              _SleepOption(
                _SleepChoice.confirm,
                Icons.check_rounded,
                "I'm up now",
                'Save your sleep until now',
              ),
              _SleepOption(
                _SleepChoice.enterTimes,
                Icons.edit_rounded,
                'Adjust times',
                'Change when you fell asleep or woke up',
              ),
            ],
          );
          if (!context.mounted) return;
          switch (choice) {
            case _SleepChoice.confirm:
              await _run(context, cubit.wakeUp);
            case _SleepChoice.enterTimes:
              final wake = DateTime.now();
              await _log(
                context,
                initial: SleepSessionInfo(
                  bedTime: since,
                  wakeTime: wake,
                  duration: wake.difference(since),
                  source: SleepDataSource.manual,
                ),
              );
            default:
          }
        },
      ),
    );
  }

  /// Last night as estimated from screen-off time: review it in a sheet,
  /// then confirm or adjust.
  Widget _confirm(
    BuildContext context,
    SleepCubit cubit,
    SleepSessionInfo estimate,
  ) {
    final time = DateFormat.jm();
    final duration = formatDashboardDuration(estimate.duration);
    // Shown like a logged night (same figure as every card), marked as an
    // estimate until the user reviews it.
    return _night(
      context,
      estimate,
      status: TrackerStatus.notLogged,
      statusLabel: 'Estimate',
      action: TrackerQuickAction(
        label: 'Review',
        icon: Icons.checklist_rounded,
        color: _metric.color,
        filled: true,
        onTap: () async {
          final choice = await _showChoices(
            context,
            title: 'Slept $duration?',
            subtitle:
                '${time.format(estimate.bedTime)} to '
                '${time.format(estimate.wakeTime)}, from when your phone '
                'was idle',
            options: const [
              _SleepOption(
                _SleepChoice.confirm,
                Icons.check_rounded,
                'Looks right',
                'Save it as last night',
              ),
              _SleepOption(
                _SleepChoice.enterTimes,
                Icons.edit_rounded,
                'Adjust times',
                'Change when you fell asleep or woke up',
              ),
            ],
          );
          if (!context.mounted) return;
          switch (choice) {
            case _SleepChoice.confirm:
              await _run(context, cubit.confirmEstimate);
            case _SleepChoice.enterTimes:
              await _log(context, initial: estimate);
            default:
          }
        },
      ),
    );
  }

  Widget _loaded(
    BuildContext context,
    SleepCubit cubit,
    SleepSessionInfo session,
  ) {
    final goalMinutes = sl<SleepService>().getGoalMinutes();
    final goalMet = session.duration.inMinutes >= goalMinutes;
    // A saved night is finished, not "on track": logged like weight and
    // mood, with "Goal met" when it reached the goal.
    return _night(
      context,
      session,
      status: TrackerStatus.done,
      statusLabel: goalMet ? null : 'Logged',
      action: session.source == SleepDataSource.healthStore
          // Health Connect nights come from the watch; they open the
          // details instead of an edit that wouldn't stick.
          ? TrackerQuickAction(
              label: 'Details',
              icon: Icons.bar_chart_rounded,
              color: _metric.color,
              onTap: () => _open(context),
            )
          : TrackerQuickAction(
              label: 'Edit',
              icon: Icons.edit_rounded,
              svgAsset: TrackerIcons.edit,
              color: _metric.color,
              onTap: () => _log(context, initial: session),
            ),
    );
  }

  /// A night against the sleep goal: the figure, goal and progress bar.
  Widget _night(
    BuildContext context,
    SleepSessionInfo session, {
    required TrackerStatus status,
    String? statusLabel,
    required Widget action,
  }) {
    final goalMinutes = sl<SleepService>().getGoalMinutes();
    final minutes = session.duration.inMinutes;
    return TrackerCard(
      metric: _metric,
      status: status,
      statusLabel: statusLabel,
      onOpen: () => _open(context),
      actions: [action],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TrackerProgress(
            value: formatDashboardDuration(session.duration),
            goal: formatDashboardDuration(Duration(minutes: goalMinutes)),
            fraction: safeFraction(minutes, goalMinutes),
            color: _metric.color,
          ),
        ],
      ),
    );
  }

  /// Sleep sheet listing [options]; returns the one tapped, or null.
  static Future<_SleepChoice?> _showChoices(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<_SleepOption> options,
  }) {
    return showAppBottomSheet<_SleepChoice>(
      context: context,
      builder: (sheetContext) => TrackerSheet(
        metric: _metric,
        title: title,
        subtitle: subtitle,
        child: AppListGroup(
          children: [
            for (final o in options)
              AppListTile(
                icon: o.icon,
                iconColor: _metric.color,
                title: o.title,
                subtitle: o.subtitle,
                onTap: () => Navigator.pop(sheetContext, o.choice),
              ),
          ],
        ),
      ),
    );
  }
}

enum _SleepChoice { enterTimes, goToBed, autoDetect, healthConnect, confirm }

/// One row in the sleep choices sheet.
class _SleepOption {
  final _SleepChoice choice;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SleepOption(this.choice, this.icon, this.title, this.subtitle);
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
