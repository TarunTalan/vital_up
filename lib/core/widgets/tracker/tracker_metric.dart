import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

/// Every metric VitalUp tracks. Each one follows the same pattern —
/// goal, daily logging, progress (home card) and insights (detail page) —
/// and is drawn with the same icon and accent everywhere.
enum TrackerMetric {
  nutrition(
    label: 'Nutrition',
    iconAsset: 'assets/icons/fork_knife.svg',
    icon: Icons.restaurant_rounded,
    color: AppColors.trackNutrition,
    route: 'diet-progress',
    logLabel: 'Log meal',
    logIcon: Icons.photo_camera_rounded,
  ),
  activity(
    label: 'Activity',
    iconAsset: 'assets/icons/barbell.svg',
    icon: Icons.directions_run_rounded,
    color: AppColors.trackActivity,
    route: 'activity-goals',
    logLabel: 'Start workout',
    logIcon: Icons.play_arrow_rounded,
  ),
  mood(
    label: 'Mood & Stress',
    iconAsset: 'assets/icons/mood.svg',
    icon: Icons.self_improvement_rounded,
    color: AppColors.trackMood,
    route: 'stress-trends',
    logLabel: 'Check in',
    logIcon: Icons.add_reaction_rounded,
  ),
  water(
    label: 'Water',
    iconAsset: 'assets/icons/drop.svg',
    icon: Icons.water_drop_rounded,
    color: AppColors.trackWater,
    route: 'water-trends',
    logLabel: 'Log water',
    logIcon: Icons.add_rounded,
  ),
  sleep(
    label: 'Sleep',
    iconAsset: 'assets/icons/moon_stars.svg',
    icon: Icons.bedtime_rounded,
    color: AppColors.trackSleep,
    route: 'sleep-trends',
    logLabel: 'Log sleep',
    logIcon: Icons.bedtime_rounded,
  ),
  weight(
    label: 'Weight',
    iconAsset: 'assets/icons/weight_icon.svg',
    icon: Icons.monitor_weight_rounded,
    color: AppColors.trackWeight,
    route: 'weight-trends',
    logLabel: 'Log weight',
    logIcon: Icons.add_rounded,
  ),
  screenTime(
    label: 'Screen Time',
    iconAsset: 'assets/icons/devices.svg',
    icon: Icons.smartphone_rounded,
    color: AppColors.trackScreenTime,
    route: 'screen-time-trends',
    logLabel: 'Usage access',
    logIcon: Icons.settings_rounded,
  );

  final String label;

  /// Brand SVG used in icon badges.
  final String iconAsset;

  /// Material fallback for small inline spots (chips, list rows).
  final IconData icon;
  final Color color;

  /// Named route of the metric's detail page.
  final String route;

  /// Verb on the metric's primary log action. Always "Log …" unless the
  /// metric logs itself differently (workout, check-in).
  final String logLabel;
  final IconData logIcon;

  const TrackerMetric({
    required this.label,
    required this.iconAsset,
    required this.icon,
    required this.color,
    required this.route,
    required this.logLabel,
    required this.logIcon,
  });

  /// Screen time is read from the device, so it has nothing to log by hand.
  bool get isAutoTracked => this == TrackerMetric.screenTime;

  /// How a day's value relates to the goal.
  GoalDirection get direction => switch (this) {
    TrackerMetric.screenTime || TrackerMetric.mood => GoalDirection.down,
    TrackerMetric.nutrition || TrackerMetric.weight => GoalDirection.near,
    _ => GoalDirection.up,
  };
}
