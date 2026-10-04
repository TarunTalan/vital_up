import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import '../../data/services/sleep_service.dart';
import '../../domain/entities/sleep_session_info.dart';
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

  Future<void> _log(BuildContext context) async {
    if (await showSleepLogSheet(context) && context.mounted) {
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
          SleepNeedsManualEntry() => TrackerCard(
            metric: _metric,
            status: TrackerStatus.notLogged,
            onOpen: () => _open(context),
            actions: [_logAction(context, filled: true)],
            child: const TrackerPrompt(
              title: 'How did you sleep?',
              message: 'Log sleep to track your rest.',
              color: AppColors.trackSleep,
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
            child: const TrackerPrompt(
              icon: Icons.health_and_safety_rounded,
              title: 'Sync sleep',
              message: 'Install Health Connect to sync your watch.',
              color: AppColors.trackSleep,
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

  Widget _logAction(BuildContext context, {bool filled = false}) =>
      TrackerQuickAction(
        label: _metric.logLabel,
        icon: _metric.logIcon,
        color: _metric.color,
        filled: filled,
        onTap: () => _log(context),
      );

  Widget _loaded(BuildContext context, SleepSessionInfo session, bool isAuto) {
    final goalMinutes = sl<SleepService>().getGoalMinutes();
    final minutes = session.duration.inMinutes;
    final time = DateFormat.jm();
    return TrackerCard(
      metric: _metric,
      status: TrackerStatus.of(
        value: minutes.toDouble(),
        goal: goalMinutes.toDouble(),
        paceFraction: 1,
      ),
      onOpen: () => _open(context),
      actions: [_logAction(context)],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TrackerProgress(
              value: formatDashboardDuration(session.duration),
              goal: formatDashboardDuration(Duration(minutes: goalMinutes)),
              fraction: minutes / goalMinutes,
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
