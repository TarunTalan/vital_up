import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/tracker_input_rules.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Goal editors for every tracker, so a goal is changed the same way from
/// its home card, detail page or the My Goals list. Each returns true when
/// the goal changed (or may have, for goals edited on another screen).

/// "2 L", "2.5 L", "2.75 L": exact, never rounded to a goal not set.
String formatWaterGoal(double ml) {
  if (ml < 1000) return '${ml.round()} ml';
  final litres = (ml / 1000).toStringAsFixed(2);
  return '${litres.replaceFirst(RegExp(r'\.?0+$'), '')} L';
}

String formatMinutesGoal(double minutes) =>
    formatDashboardDuration(Duration(minutes: minutes.round()));

Future<bool> editWaterGoal(BuildContext context) async {
  final service = sl<WaterIntakeService>();
  final latest = await sl<WeightService>().latest();
  if (!context.mounted) return false;
  final recommended = latest == null
      ? null
      : recommendedWaterGoalMl(latest.weightKg).toDouble();
  final goal = service.getDailyGoal();
  var removed = false;
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.water,
    title: 'Daily water goal',
    description: 'How much to drink each day',
    initial: (goal ?? recommended ?? 2500).toDouble(),
    min: InputLimits.waterGoalMlMin.toDouble(),
    max: InputLimits.waterGoalMlMax.toDouble(),
    step: 250,
    format: formatWaterGoal,
    recommended: recommended,
    recommendedReason: 'About 35 ml per kg of your body weight',
    onRemove: goal == null
        ? null
        : () async {
            await service.clearDailyGoal();
            removed = true;
          },
    removeMessage:
        "You can keep logging water, but days won't earn Arena points "
        'or count toward water badges.',
  );
  if (value == null) return removed;
  await service.setDailyGoal(value.round());
  return true;
}

Future<bool> editSleepGoal(BuildContext context) async {
  final service = sl<SleepService>();
  final goal = service.getGoalMinutes();
  var removed = false;
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.sleep,
    title: 'Nightly sleep goal',
    description: 'Hours of sleep to aim for each night',
    initial: (goal ?? SleepService.defaultGoalMinutes).toDouble(),
    min: InputLimits.sleepGoalMinMin.toDouble(),
    max: InputLimits.sleepGoalMinMax.toDouble(),
    step: 30,
    format: formatMinutesGoal,
    recommended: SleepService.defaultGoalMinutes.toDouble(),
    recommendedReason: 'Adults need 7–9 hours a night',
    onRemove: goal == null
        ? null
        : () async {
            await service.clearGoal();
            removed = true;
          },
  );
  if (value == null) return removed;
  await service.setGoalMinutes(value.round());
  return true;
}

Future<bool> editScreenTimeGoal(BuildContext context) async {
  final service = sl<ScreenTimeService>();
  final limit = service.getDailyLimitMinutes();
  var removed = false;
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.screenTime,
    title: 'Daily screen time limit',
    description: 'Stay under this to meet your goal',
    initial: (limit ?? 120).toDouble(),
    min: screenLimitMinMinutes.toDouble(),
    max: screenLimitMaxMinutes.toDouble(),
    step: 15,
    format: formatMinutesGoal,
    recommended: 120,
    recommendedReason: 'A common target for leisure screen time',
    onRemove: limit == null
        ? null
        : () async {
            await service.clearDailyLimit();
            removed = true;
          },
  );
  if (value == null) return removed;
  await service.setDailyLimitMinutes(value.round());
  return true;
}

Future<bool> editWeightGoal(BuildContext context) async {
  final service = sl<WeightService>();
  final unit = await service.unit();
  final target = await service.targetKg();
  final latest = await service.latest();
  if (!context.mounted) return false;
  final start = target ?? latest?.weightKg ?? 70;
  var removed = false;
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.weight,
    title: 'Goal weight',
    description: 'The weight you are working towards',
    initial: (unit.fromKg(start) * 2).round() / 2,
    min: unit.minValue.toDouble(),
    max: unit.maxValue.toDouble(),
    step: 0.5,
    format: (v) => '${v.toStringAsFixed(1)} ${unit.label}',
    onRemove: target == null
        ? null
        : () async {
            await service.clearTarget();
            removed = true;
          },
  );
  if (value == null) return removed;
  await service.setTargetKg(unit.toKg(value));
  return true;
}

/// Calories come from the diet plan: edit the plan, or create one.
Future<bool> editNutritionGoal(BuildContext context) async {
  final plan = await sl<GetActiveMealPlan>()();
  if (!context.mounted) return false;
  await context.pushNamed(plan == null ? 'diet-plan-prefs' : 'diet-plan-edit');
  return true;
}

/// Activity has several goals (steps, distance…), managed on its page.
Future<bool> editActivityGoals(BuildContext context) async {
  await context.pushNamed(TrackerMetric.activity.route);
  return true;
}

/// Opens the right goal editor for [metric]. Mood has no editable goal —
/// its goal is a daily check-in.
Future<bool> editTrackerGoal(BuildContext context, TrackerMetric metric) =>
    switch (metric) {
      TrackerMetric.water => editWaterGoal(context),
      TrackerMetric.sleep => editSleepGoal(context),
      TrackerMetric.screenTime => editScreenTimeGoal(context),
      TrackerMetric.weight => editWeightGoal(context),
      TrackerMetric.nutrition => editNutritionGoal(context),
      TrackerMetric.activity => editActivityGoals(context),
      TrackerMetric.mood => Future.value(false),
    };
