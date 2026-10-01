import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/circular_sleep_clock.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

/// Sleep trend: hours per night vs goal, goal stepper, sleep quality stats,
/// and interactive circular clock logging.
class SleepTrendsPage extends StatelessWidget {
  const SleepTrendsPage({super.key});

  static const _goalStepMin = 30;
  static const _minGoalMin = 240;
  static const _maxGoalMin = 720;

  static String formatHours(double hours) =>
      formatDashboardDuration(Duration(minutes: (hours * 60).round()));

  @override
  Widget build(BuildContext context) {
    final sleep = sl<SleepService>();

    return BlocProvider(
      create: (_) => TrendCubit<SleepSessionInfo>(sl<TrendsService>().sleep)
        ..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<SleepSessionInfo>>();
          return TrendDetailScaffold<SleepSessionInfo>(
            title: 'Sleep',
            color: AppColors.sleep,
            format: formatHours,
            logsTitle: 'Nights & Quality',
            bottomBar: AppPrimaryButton(
              label: 'Log sleep with Clock',
              onTap: () async {
                final saved = await showAppBottomSheet<bool>(
                  context: context,
                  builder: (_) => const _SleepEntrySheet(),
                );
                if (saved == true) cubit.load();
              },
            ),
            header: (context, data) {
              final goal = sleep.getGoalMinutes();
              Future<void> setGoal(int value) async {
                await sleep.setGoalMinutes(value.clamp(_minGoalMin, _maxGoalMin));
                cubit.load();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GoalStepperCard(
                    label: 'Nightly goal',
                    value: formatDashboardDuration(Duration(minutes: goal)),
                    onDecrease: goal > _minGoalMin
                        ? () => setGoal(goal - _goalStepMin)
                        : null,
                    onIncrease: goal < _maxGoalMin
                        ? () => setGoal(goal + _goalStepMin)
                        : null,
                  ),
                  const SizedBox(height: AppDimens.space12),
                  FutureBuilder<SleepStats>(
                    future: sleep.getWeeklyStats(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.nightsLogged == 0) {
                        return const SizedBox.shrink();
                      }
                      final stats = snapshot.data!;
                      return _SleepScoreSummaryCard(stats: stats);
                    },
                  ),
                ],
              );
            },
            logBuilder: (context, night) {
              final time = DateFormat.jm();
              final score = night.sleepScore;
              Color scoreColor;
              if (score >= 85) {
                scoreColor = AppColors.success;
              } else if (score >= 70) {
                scoreColor = AppColors.teal;
              } else if (score >= 50) {
                scoreColor = AppColors.warning;
              } else {
                scoreColor = AppColors.error;
              }

              return TrendLogTile(
                icon: night.source == SleepDataSource.healthStore
                    ? Icons.watch_rounded
                    : Icons.bedtime_rounded,
                color: scoreColor,
                title: DateFormat('EEE d MMM').format(night.wakeTime),
                subtitle:
                    '${time.format(night.bedTime)} – ${time.format(night.wakeTime)}'
                    ' · Score: $score% (${night.scoreCategory})',
                trailing: formatDashboardDuration(night.duration),
              );
            },
          );
        },
      ),
    );
  }
}

class _SleepScoreSummaryCard extends StatelessWidget {
  final SleepStats stats;

  const _SleepScoreSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space16),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Recovery & Insights',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: AppDimens.space2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sleep.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                ),
                child: Text(
                  'Avg Score: ${stats.averageScore}%',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.sleep,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  title: 'Consistency',
                  value: '${stats.consistencyScore}%',
                  subtitle: stats.consistencyScore >= 80 ? 'Regular' : 'Variable',
                  icon: Icons.repeat_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _MetricPill(
                  title: 'Sleep Debt',
                  value: stats.totalSleepDebt.inMinutes > 0
                      ? formatDashboardDuration(stats.totalSleepDebt)
                      : '0m',
                  subtitle: stats.totalSleepDebt.inMinutes > 60
                      ? 'Deficit'
                      : 'Optimal',
                  icon: Icons.hourglass_bottom_rounded,
                  color: stats.totalSleepDebt.inMinutes > 60
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricPill({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space10,
      ),
      decoration: BoxDecoration(
        color: v.primaryFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: v.primaryBorder!),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppDimens.iconSm, color: color),
          const SizedBox(width: AppDimens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.labelSmall?.copyWith(color: v.grayText),
                ),
                Text(
                  value,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bed / wake time interactive circular clock picker for last night
class _SleepEntrySheet extends StatefulWidget {
  const _SleepEntrySheet();

  @override
  State<_SleepEntrySheet> createState() => _SleepEntrySheetState();
}

class _SleepEntrySheetState extends State<_SleepEntrySheet> {
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wake = today.add(Duration(hours: _wake.hour, minutes: _wake.minute));
    var bed = today.add(Duration(hours: _bed.hour, minutes: _bed.minute));
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    await sl<SleepService>().saveManualEntry(bed, wake);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Log last night', style: context.text.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space12),
            CircularSleepClockPicker(
              initialBedTime: _bed,
              initialWakeTime: _wake,
              onChanged: (b, w) {
                setState(() {
                  _bed = b;
                  _wake = w;
                });
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Save Sleep',
              isLoading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
