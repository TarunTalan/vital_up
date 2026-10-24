import 'dart:math' as math;

/// Everything Vita knows about the user right now, gathered from on-device
/// data (meal logs, sleep, water, screen time, activity, Health Connect /
/// Apple Health steps and sleep, onboarding profile, active diet plan).
///
/// Every field is optional: absent means "no data", never zero.
class HealthSnapshot {
  final DateTime takenAt;
  final ProfileSnapshot profile;

  // Diet
  final int mealsToday;
  final int caloriesToday;
  final int? calorieGoal;
  final int mealsThisWeek;
  final int daysWithMealsThisWeek;
  final int? avgCaloriesPerDay;
  final List<String> todayMealSummaries;

  // Sleep
  final double? sleepLastNightHours;
  final double? sleepAvgHours;
  final int sleepNightsLogged;

  // Hydration
  final int? waterTodayMl;

  /// Null when the user has no water goal.
  final int? waterGoalMl;
  final bool tracksWater;

  // Screen time (today, Android only)
  final int? screenTimeTodayMinutes;

  // Activity
  final int? stepsToday;
  final int workoutsThisWeek;
  final double distanceThisWeekKm;
  final int activeMinutesThisWeek;

  // Active diet plan meal lines ("Breakfast · 420 kcal · Poha, Chai").
  final List<String> dietPlanMeals;

  // Where figures came from. Health Connect parts leave the AI payload
  // unless the user opted in (see [forAi]); on-device features use all.
  final bool stepsFromHealthConnect;

  /// Steps counted by this app's own workouts today.
  final int? workoutStepsToday;
  final bool sleepLastNightFromHealthConnect;

  /// Sleep from saved entries only (manual / phone estimate).
  final double? loggedSleepLastNightHours;
  final double? loggedSleepAvgHours;
  final int loggedSleepNights;

  /// Workouts imported from Health Connect (included in the totals above).
  final int importedWorkoutsThisWeek;
  final double importedDistanceThisWeekKm;
  final int importedActiveMinutesThisWeek;

  const HealthSnapshot({
    required this.takenAt,
    required this.profile,
    this.mealsToday = 0,
    this.caloriesToday = 0,
    this.calorieGoal,
    this.mealsThisWeek = 0,
    this.daysWithMealsThisWeek = 0,
    this.avgCaloriesPerDay,
    this.todayMealSummaries = const [],
    this.sleepLastNightHours,
    this.sleepAvgHours,
    this.sleepNightsLogged = 0,
    this.waterTodayMl,
    this.waterGoalMl = 2500,
    this.tracksWater = false,
    this.screenTimeTodayMinutes,
    this.stepsToday,
    this.workoutsThisWeek = 0,
    this.distanceThisWeekKm = 0,
    this.activeMinutesThisWeek = 0,
    this.dietPlanMeals = const [],
    this.stepsFromHealthConnect = false,
    this.workoutStepsToday,
    this.sleepLastNightFromHealthConnect = false,
    this.loggedSleepLastNightHours,
    this.loggedSleepAvgHours,
    this.loggedSleepNights = 0,
    this.importedWorkoutsThisWeek = 0,
    this.importedDistanceThisWeekKm = 0,
    this.importedActiveMinutesThisWeek = 0,
  });

  /// What may be sent to the AI. Without the user's Health Connect opt-in,
  /// Health Connect steps and sleep, and imported workouts are left
  /// out; only data logged in this app remains.
  HealthSnapshot forAi({required bool includeHealthConnect}) {
    if (includeHealthConnect) return this;
    return HealthSnapshot(
      takenAt: takenAt,
      profile: profile,
      mealsToday: mealsToday,
      caloriesToday: caloriesToday,
      calorieGoal: calorieGoal,
      mealsThisWeek: mealsThisWeek,
      daysWithMealsThisWeek: daysWithMealsThisWeek,
      avgCaloriesPerDay: avgCaloriesPerDay,
      todayMealSummaries: todayMealSummaries,
      sleepLastNightHours: loggedSleepLastNightHours,
      sleepAvgHours: loggedSleepAvgHours,
      sleepNightsLogged: loggedSleepNights,
      waterTodayMl: waterTodayMl,
      waterGoalMl: waterGoalMl,
      tracksWater: tracksWater,
      screenTimeTodayMinutes: screenTimeTodayMinutes,
      stepsToday: stepsFromHealthConnect ? workoutStepsToday : stepsToday,
      workoutsThisWeek: math.max(
        0,
        workoutsThisWeek - importedWorkoutsThisWeek,
      ),
      distanceThisWeekKm: math.max(
        0,
        distanceThisWeekKm - importedDistanceThisWeekKm,
      ),
      activeMinutesThisWeek: math.max(
        0,
        activeMinutesThisWeek - importedActiveMinutesThisWeek,
      ),
      dietPlanMeals: dietPlanMeals,
      workoutStepsToday: workoutStepsToday,
      loggedSleepLastNightHours: loggedSleepLastNightHours,
      loggedSleepAvgHours: loggedSleepAvgHours,
      loggedSleepNights: loggedSleepNights,
    );
  }

  bool get logsMeals => mealsThisWeek > 0;

  /// Compact JSON for the Vita edge function; nulls and empties are dropped
  /// so the model can't mistake "no data" for a real zero.
  Map<String, dynamic> toJson() => _compact({
    'now': takenAt.toIso8601String(),
    'profile': profile.toJson(),
    'diet': {
      'mealsToday': mealsToday,
      'caloriesToday': caloriesToday,
      'calorieGoal': calorieGoal,
      'todayMeals': todayMealSummaries,
      'mealsLoggedLast7Days': mealsThisWeek,
      'daysWithMealsLast7Days': daysWithMealsThisWeek,
      'avgCaloriesPerLoggedDay': avgCaloriesPerDay,
    },
    'sleep': {
      'lastNightHours': sleepLastNightHours,
      'avgHoursLast7Days': sleepAvgHours,
      'nightsLogged': sleepNightsLogged,
    },
    if (tracksWater)
      'hydration': {'todayMl': waterTodayMl, 'goalMl': waterGoalMl},
    'screenTimeTodayMinutes': screenTimeTodayMinutes,
    'activity': {
      'stepsToday': stepsToday,
      'workoutsLast7Days': workoutsThisWeek,
      'distanceLast7DaysKm': double.parse(
        distanceThisWeekKm.toStringAsFixed(1),
      ),
      'activeMinutesLast7Days': activeMinutesThisWeek,
    },
    'activeDietPlan': dietPlanMeals,
  });
}

class ProfileSnapshot {
  final int? age;
  final String? gender;
  final double? weightKg;
  final double? heightCm;
  final String? goalType;
  final double? targetWeightKg;
  final String? dietaryPreference;
  final String? healthConditions;
  final String? allergies;
  final String? medicines;
  final String? smokes;
  final String? activityLevel;
  final int? bloodPressureTop;
  final int? bloodPressureBottom;

  const ProfileSnapshot({
    this.age,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.goalType,
    this.targetWeightKg,
    this.dietaryPreference,
    this.healthConditions,
    this.allergies,
    this.medicines,
    this.smokes,
    this.activityLevel,
    this.bloodPressureTop,
    this.bloodPressureBottom,
  });

  bool get hasMedicines => _meaningful(medicines);

  Map<String, dynamic> toJson() => {
    'age': age,
    'gender': gender,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'goal': goalType,
    'targetWeightKg': targetWeightKg,
    'dietaryPreference': dietaryPreference,
    'healthConditions': healthConditions,
    'allergies': allergies,
    'medicines': medicines,
    'smokes': smokes,
    'activityLevel': activityLevel,
    if (bloodPressureTop != null && bloodPressureBottom != null)
      'selfReportedBloodPressure': '$bloodPressureTop/$bloodPressureBottom',
  };
}

bool _meaningful(String? value) {
  final v = value?.trim().toLowerCase() ?? '';
  return v.isNotEmpty && v != 'none' && v != 'no' && v != 'n/a' && v != '[]';
}

/// Strips nulls, empty strings/lists/maps recursively.
Map<String, dynamic> _compact(Map<String, dynamic> map) {
  final out = <String, dynamic>{};
  map.forEach((key, value) {
    final v = value is Map<String, dynamic> ? _compact(value) : value;
    if (v == null) return;
    if (v is String && v.trim().isEmpty) return;
    if (v is Iterable && v.isEmpty) return;
    if (v is Map && v.isEmpty) return;
    out[key] = v;
  });
  return out;
}

/// Profile strings from onboarding: blank / "none" mean no answer.
String? meaningfulOrNull(String? value) =>
    _meaningful(value) ? value!.trim() : null;
