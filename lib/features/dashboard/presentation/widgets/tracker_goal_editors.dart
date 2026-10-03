import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Goal editors for every tracker, so a goal is changed the same way from
/// its home card, detail page or the My Goals list. Each returns true when
/// the goal changed (or may have, for goals edited on another screen).

String formatWaterGoal(double ml) => ml >= 1000
    ? '${(ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1)} L'
    : '${ml.round()} ml';

String formatMinutesGoal(double minutes) =>
    formatDashboardDuration(Duration(minutes: minutes.round()));

Future<bool> editWaterGoal(BuildContext context) async {
  final service = sl<WaterIntakeService>();
  final latest = await sl<WeightService>().latest();
  if (!context.mounted) return false;
  // ~35 ml per kg of body weight, rounded to a glass.
  final recommended = latest == null
      ? null
      : ((latest.weightKg * 35 / 250).round() * 250)
            .clamp(1500, 4000)
            .toDouble();
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.water,
    title: 'Daily water goal',
    description: 'How much to drink each day',
    initial: service.getDailyGoal().toDouble(),
    min: 500,
    max: 6000,
    step: 250,
    format: formatWaterGoal,
    recommended: recommended,
    recommendedReason: 'About 35 ml per kg of your body weight',
  );
  if (value == null) return false;
  await service.setDailyGoal(value.round());
  return true;
}

Future<bool> editSleepGoal(BuildContext context) async {
  final service = sl<SleepService>();
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.sleep,
    title: 'Nightly sleep goal',
    description: 'Hours of sleep to aim for each night',
    initial: service.getGoalMinutes().toDouble(),
    min: 240,
    max: 720,
    step: 30,
    format: formatMinutesGoal,
    recommended: SleepService.defaultGoalMinutes.toDouble(),
    recommendedReason: 'Adults need 7–9 hours a night',
  );
  if (value == null) return false;
  await service.setGoalMinutes(value.round());
  return true;
}

Future<bool> editScreenTimeGoal(BuildContext context) async {
  final service = sl<ScreenTimeService>();
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.screenTime,
    title: 'Daily screen time limit',
    description: 'Stay under this to meet your goal',
    initial: service.getDailyLimitMinutes().toDouble(),
    min: 30,
    max: 600,
    step: 30,
    format: formatMinutesGoal,
    recommended: 120,
    recommendedReason: 'A common target for leisure screen time',
  );
  if (value == null) return false;
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
  final value = await showTrackerGoalSheet(
    context: context,
    metric: TrackerMetric.weight,
    title: 'Goal weight',
    description: 'The weight you are working towards',
    initial: (unit.fromKg(start) * 2).round() / 2,
    min: unit.fromKg(30).roundToDouble(),
    max: unit.fromKg(250).roundToDouble(),
    step: 0.5,
    format: (v) => '${v.toStringAsFixed(1)} ${unit.label}',
  );
  if (value == null) return false;
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
