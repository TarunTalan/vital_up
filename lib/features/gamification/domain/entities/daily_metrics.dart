import 'package:equatable/equatable.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';

/// One day's on-device numbers, reported to `submit_daily_report`. The
/// server clamps and caps them and decides the points.
class DailyMetrics extends Equatable {
  final DateTime day;

  // Fitness
  final int steps;
  final int distanceMeters;
  final int activeMinutes;
  final int caloriesBurned;

  /// Tracked workouts of 10 minutes or more.
  final int workouts;
  final Set<GoalMetric> dailyGoalsAchieved;
  final Set<GoalMetric> weeklyGoalsAchieved;

  // Nutrition
  final int foodLogs;
  final int waterLogs;
  final bool waterGoalMet;
  final int plannedMeals;
  final int plannedMealsLogged;
  final bool calorieGoalMet;

  // Lifestyle
  final bool sleepLogged;
  final double sleepHours;
  final bool moodCheckIn;

  /// Stress check-in level 1 (very calm) – 5 (very stressed); 0 when none.
  final int moodLevel;

  const DailyMetrics({
    required this.day,
    this.steps = 0,
    this.distanceMeters = 0,
    this.activeMinutes = 0,
    this.caloriesBurned = 0,
    this.workouts = 0,
    this.dailyGoalsAchieved = const {},
    this.weeklyGoalsAchieved = const {},
    this.foodLogs = 0,
    this.waterLogs = 0,
    this.waterGoalMet = false,
    this.plannedMeals = 0,
    this.plannedMealsLogged = 0,
    this.calorieGoalMet = false,
    this.sleepLogged = false,
    this.sleepHours = 0,
    this.moodCheckIn = false,
    this.moodLevel = 0,
  });

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'distance_m': distanceMeters,
    'active_minutes': activeMinutes,
    'calories': caloriesBurned,
    'workouts': workouts,
    'daily_goals': [for (final g in dailyGoalsAchieved) g.name],
    'weekly_goals': [for (final g in weeklyGoalsAchieved) g.name],
    'food_logs': foodLogs,
    'water_logs': waterLogs,
    'water_goal_met': waterGoalMet,
    'planned_meals': plannedMeals,
    'planned_meals_logged': plannedMealsLogged,
    'calorie_goal_met': calorieGoalMet,
    'sleep_logged': sleepLogged,
    'sleep_hours': double.parse(sleepHours.toStringAsFixed(2)),
    'mood_checkin': moodCheckIn,
    'mood_level': moodLevel,
  };

  @override
  List<Object?> get props => [
    day,
    steps,
    distanceMeters,
    activeMinutes,
    caloriesBurned,
    workouts,
    dailyGoalsAchieved,
    weeklyGoalsAchieved,
    foodLogs,
    waterLogs,
    waterGoalMet,
    plannedMeals,
    plannedMealsLogged,
    calorieGoalMet,
    sleepLogged,
    sleepHours,
    moodCheckIn,
    moodLevel,
  ];
}
