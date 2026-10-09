import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/weekly_summary/weekly_summary_service.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// "Your week": the last 7 days next to the 7 before, per habit.
class WeeklySummaryPage extends StatefulWidget {
  const WeeklySummaryPage({super.key});

  @override
  State<WeeklySummaryPage> createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends State<WeeklySummaryPage> {
  late Future<(WeeklySummary, WeightUnit)> _data = _load();

  Future<(WeeklySummary, WeightUnit)> _load() async => (
    await sl<WeeklySummaryService>().load(),
    await sl<WeightService>().unit(),
  );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      onRefresh: () async {
        final next = _load();
        // Block body: a setState callback must not return the Future.
        setState(() {
          _data = next;
        });
        try {
          await next;
        } catch (_) {
          // Shown by the FutureBuilder below.
        }
      },
      header: const AppPageHeader(title: 'Your week'),
      body: FutureBuilder<(WeeklySummary, WeightUnit)>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return LoadErrorView(
              onRetry: () => setState(() {
                _data = _load();
              }),
            );
          }
          final data = snap.data;
          if (data == null) return const Center(child: VitalUpLoader());
          final (summary, unit) = data;
          return _Summary(summary: summary, unit: unit);
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final WeeklySummary summary;
  final WeightUnit unit;

  const _Summary({required this.summary, required this.unit});

  static String _duration(Duration d) =>
      '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

  @override
  Widget build(BuildContext context) {
    final now = summary.thisWeek;
    final before = summary.lastWeek;
    final range =
        '${DateFormat('d MMM').format(now.from)} – '
        '${DateFormat('d MMM').format(DateTime.now())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          range,
          style: context.text.bodyMedium?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        Text(
          now.isEmpty
              ? 'Nothing logged this week yet. Small steps count — start with '
                    'a glass of water.'
              : _headline(now, before),
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: AppDimens.sectionGap),
        _MetricCard(
          icon: Icons.directions_run_rounded,
          color: AppColors.activitySteps,
          title: 'Workouts',
          value: '${now.workouts}',
          detail:
              '${now.activeMinutes} min · '
              '${now.distanceKm.toStringAsFixed(1)} km',
          change: now.workouts - before.workouts,
        ),
        _MetricCard(
          icon: Icons.bedtime_rounded,
          color: AppColors.sleep,
          title: 'Average sleep',
          value: now.avgSleep == null ? '—' : _duration(now.avgSleep!),
          detail: before.avgSleep == null
              ? 'No sleep recorded the week before'
              : 'Week before: ${_duration(before.avgSleep!)}',
          change: now.avgSleep == null || before.avgSleep == null
              ? null
              : now.avgSleep!.inMinutes - before.avgSleep!.inMinutes,
          changeUnit: ' min',
        ),
        _MetricCard(
          icon: Icons.water_drop_rounded,
          color: AppColors.water,
          title: 'Water goal met',
          value: '${now.waterGoalDays}/7 days',
          detail: '${(now.waterMl / 1000).toStringAsFixed(1)} L in total',
          change: now.waterGoalDays - before.waterGoalDays,
          changeUnit: ' days',
        ),
        _MetricCard(
          icon: Icons.restaurant_rounded,
          color: AppColors.scoreNutrition,
          title: 'Meals logged',
          value: '${now.meals}',
          detail: 'On ${now.mealDays} of 7 days',
          change: now.meals - before.meals,
        ),
        _MetricCard(
          icon: Icons.monitor_weight_rounded,
          color: AppColors.teal,
          title: 'Weight change',
          value: now.weightChangeKg == null
              ? '—'
              : '${now.weightChangeKg! >= 0 ? '+' : '−'}'
                    '${unit.fromKg(now.weightChangeKg!.abs()).toStringAsFixed(1)} '
                    '${unit.label}',
          detail: now.weightChangeKg == null
              ? 'Weigh in twice a week to see a change'
              : 'First to last weigh-in this week',
        ),
      ],
    );
  }

  static String _headline(WeekStats now, WeekStats before) {
    if (now.workouts > before.workouts) {
      return 'More active than last week. Keep it going.';
    }
    if (now.waterGoalDays >= 5) return 'Great hydration this week.';
    if (now.mealDays >= 5) return 'Consistent meal logging. Nice work.';
    return 'Here\'s how your week went.';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String detail;

  /// Difference vs the week before; null hides the badge.
  final int? change;
  final String changeUnit;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.detail,
    this.change,
    this.changeUnit = '',
  });

  @override
  Widget build(BuildContext context) {
    final change = this.change;
    final v = context.vColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
      child: AppCard(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              title: title,
              icon: icon,
              badgeColor: color,
              trailing: change == null || change == 0
                  ? null
                  : Text(
                      '${change > 0 ? '▲' : '▼'} ${change.abs()}$changeUnit',
                      style: context.text.labelLarge?.copyWith(
                        color: change > 0 ? v.success : v.grayText,
                      ),
                    ),
            ),
            const SizedBox(height: AppDimens.space12),
            Text(value, style: context.text.headlineMedium),
            const SizedBox(height: AppDimens.space4),
            Text(
              detail,
              style: context.text.bodySmall?.copyWith(color: v.grayText),
            ),
          ],
        ),
      ),
    );
  }
}
