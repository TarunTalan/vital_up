import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Every tracker's goal in one list, each editable with the same editor
/// its detail page uses.
class MyGoalsPage extends StatefulWidget {
  const MyGoalsPage({super.key});

  @override
  State<MyGoalsPage> createState() => _MyGoalsPageState();
}

class _MyGoalsPageState extends State<MyGoalsPage> {
  late Future<Map<TrackerMetric, String?>> _goals = _load();

  Future<Map<TrackerMetric, String?>> _load() =>
      _read().withLoadTimeout().catchError((Object e, StackTrace stack) {
        debugPrint('My goals failed to load: $e');
        debugPrintStack(stackTrace: stack);
        throw e;
      });

  Future<Map<TrackerMetric, String?>> _read() async {
    // The meal plan may need the network: offline it just shows no goal.
    final plan = await sl<GetActiveMealPlan>()().orFallback(null);
    final weight = sl<WeightService>();
    final unit = await weight.unit();
    final target = await weight.targetKg();
    final activity = sl<ActivityGoalsRepository>().getGoals();
    return {
      TrackerMetric.nutrition: plan == null
          ? null
          : '${NumberFormat.decimalPattern().format(plan.totalCalories)} kcal a day',
      TrackerMetric.activity: activity.isEmpty
          ? null
          : activity
                .map(
                  (g) =>
                      '${g.metric.formatWithUnit(g.target)} '
                      '${g.period.label.toLowerCase()}',
                )
                .join(' · '),
      TrackerMetric.mood: 'Check in once a day',
      TrackerMetric.water:
          '${formatWaterGoal(sl<WaterIntakeService>().getDailyGoal().toDouble())} a day',
      TrackerMetric.sleep:
          '${formatMinutesGoal(sl<SleepService>().getGoalMinutes().toDouble())} a night',
      TrackerMetric.weight: target == null ? null : unit.format(target),
      TrackerMetric.screenTime:
          'Under ${formatMinutesGoal(sl<ScreenTimeService>().getDailyLimitMinutes().toDouble())} a day',
    };
  }

  Future<void> _edit(TrackerMetric metric) async {
    // Mood's goal is fixed (check in daily), so open its page instead.
    if (metric == TrackerMetric.mood) {
      await context.pushNamed(metric.route);
      return;
    }
    if (await editTrackerGoal(context, metric) && mounted) {
      setState(() => _goals = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(
        title: 'My Goals',
        subtitle: 'What you are aiming for each day',
      ),
      onRefresh: () async {
        final next = _load();
        setState(() => _goals = next);
        try {
          await next;
        } catch (_) {
          // Shown by the FutureBuilder below.
        }
      },
      body: FutureBuilder<Map<TrackerMetric, String?>>(
        future: _goals,
        builder: (context, snap) {
          if (snap.hasError) {
            return LoadErrorView(
              onRetry: () {
                setState(() => _goals = _load());
              },
            );
          }
          final goals = snap.data;
          if (goals == null) return const TrackerLoading();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final metric in TrackerMetric.values) ...[
                _GoalRow(
                  metric: metric,
                  goal: goals[metric],
                  onTap: () => _edit(metric),
                ),
                const SizedBox(height: AppDimens.cardGap),
              ],
              const AppInfoNote(
                message:
                    'Goals drive the status on your home cards, the '
                    'goal line on every chart and your streaks.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final TrackerMetric metric;
  final String? goal;
  final VoidCallback onTap;

  const _GoalRow({
    required this.metric,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final editable = metric != TrackerMetric.mood;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      child: Row(
        children: [
          TrackerBadge(metric),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: context.text.titleSmall),
                const SizedBox(height: AppDimens.space2),
                Text(
                  goal ?? 'No goal set',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: goal == null ? metric.color : grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          !editable
              ? Icon(Icons.chevron_right_rounded, size: AppDimens.iconMd, color: grey)
              : goal == null
              ? Icon(Icons.add_circle_outline_rounded, size: AppDimens.iconMd, color: metric.color)
              : SvgPicture.asset(
                  'assets/icons/edit.svg', 
                  width: AppDimens.iconMd, 
                  height: AppDimens.iconMd, 
                  colorFilter: ColorFilter.mode(grey!, BlendMode.srcIn),
                ),
        ],
      ),
    );
  }
}
