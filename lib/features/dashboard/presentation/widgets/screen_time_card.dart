import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import '../../data/services/screen_time_service.dart';
import '../../domain/entities/app_usage_info.dart';
import '../cubit/screen_time_cubit.dart';
import '../cubit/screen_time_state.dart';
import 'dashboard_card_header.dart';
import 'tracker_goal_editors.dart';

const _metric = TrackerMetric.screenTime;

/// Home card: today's screen time against the daily limit and the apps
/// behind it. Tracked automatically, so there is nothing to log.
class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({super.key});

  static const _topApps = 3;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<ScreenTimeCubit>();
    await context.pushNamed(_metric.route);
    cubit.loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScreenTimeCubit, ScreenTimeState>(
      builder: (context, state) {
        final cubit = context.read<ScreenTimeCubit>();
        return switch (state) {
          ScreenTimeLoaded() => _loaded(context, state),
          ScreenTimePermissionDenied() => TrackerCard(
            metric: _metric,
            actions: [
              TrackerQuickAction(
                label: 'Allow usage access',
                icon: Icons.lock_open_rounded,
                color: _metric.color,
                filled: true,
                onTap: cubit.openSettings,
              ),
            ],
            child: const TrackerPrompt(
              title: 'Track screen time',
              message: 'Grant Usage Access to total your screen time.',
              color: AppColors.trackScreenTime,
            ),
          ),
          ScreenTimeError() => TrackerCardPlaceholder(
            metric: _metric,
            onRetry: cubit.loadStats,
          ),
          _ => const TrackerCardPlaceholder(metric: _metric),
        };
      },
    );
  }

  Widget _loaded(BuildContext context, ScreenTimeLoaded state) {
    final limit = sl<ScreenTimeService>().getDailyLimitMinutes();
    final minutes = state.totalDuration.inMinutes;
    final left = limit - minutes;
    return TrackerCard(
      metric: _metric,
      status: TrackerStatus.of(
        value: minutes.toDouble(),
        goal: limit.toDouble(),
        direction: _metric.direction,
      ),
      onOpen: () => _open(context),
      actions: [
        TrackerQuickAction(
          label: 'Edit Goal',
          svgAsset: 'assets/icons/edit.svg',
          color: _metric.color,
          filled: true,
          onTap: () async {
            if (await editScreenTimeGoal(context)) {
              if (context.mounted) context.read<ScreenTimeCubit>().loadStats();
            }
          },
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TrackerProgress(
              value: formatDashboardDuration(state.totalDuration),
              goal: '${formatDashboardDuration(Duration(minutes: limit))} limit',
              fraction: limit > 0 ? minutes / limit : null,
              color: left >= 0 ? _metric.color : context.colors.error,
              caption: left >= 0
                  ? '${formatDashboardDuration(Duration(minutes: left))} left today'
                  : 'Over by ${formatDashboardDuration(Duration(minutes: -left))}',
            ),
          ],
        ),
      ),
    );
  }
}

/// Apps ranked by time used, with a share-of-total bar.
class TopAppsList extends StatelessWidget {
  final List<AppUsageInfo> apps;

  const TopAppsList({super.key, required this.apps});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    if (apps.isEmpty) {
      return Text(
        'No app usage recorded today.',
        style: context.text.bodyMedium?.copyWith(color: grey),
      );
    }
    final top = apps.first.usageDuration.inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final app in apps) ...[
          Row(
            children: [
              AppIconBadge(
                color: _metric.color,
                size: AppDimens.avatarSmall,
                icon: Text(
                  app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                  style: context.text.labelSmall?.copyWith(
                    color: _metric.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          formatDashboardDuration(app.usageDuration),
                          style: context.text.bodySmall?.copyWith(color: grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.space4),
                    AppProgressBar(
                      value: top > 0 ? app.usageDuration.inMinutes / top : 0,
                      color: _metric.color,
                      height: AppDimens.space4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
        ],
      ],
    );
  }
}
