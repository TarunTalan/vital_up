/// Everything Vita knows about the user right now, gathered from on-device
/// data (meal logs, sleep, water, screen time, activity, Health Connect /
/// Apple Health vitals, onboarding profile, active diet plan).
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
  final int waterGoalMl;
  final bool tracksWater;

  // Screen time (today, Android only)
  final int? screenTimeTodayMinutes;

  // Activity
  final int? stepsToday;
  final int workoutsThisWeek;
  final double distanceThisWeekKm;
  final int activeMinutesThisWeek;

  // Vitals (wearable via Health Connect / Apple Health)
  final VitalsSnapshot vitals;

  // Active diet plan meal lines ("Breakfast · 420 kcal · Poha, Chai").
  final List<String> dietPlanMeals;

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
    this.vitals = const VitalsSnapshot(),
    this.dietPlanMeals = const [],
  });

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
          'distanceLast7DaysKm': double.parse(distanceThisWeekKm.toStringAsFixed(1)),
          'activeMinutesLast7Days': activeMinutesThisWeek,
        },
        'vitals': vitals.toJson(),
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

class VitalsSnapshot {
  final bool connected;
  final int? avgHeartRate;
  final int? restingHeartRate;
  final int? restingHeartRateBaseline;
  final double? hrvMs;
  final double? hrvBaselineMs;
  final int? spo2Percent;
  final int? systolic;
  final int? diastolic;

  const VitalsSnapshot({
    this.connected = false,
    this.avgHeartRate,
    this.restingHeartRate,
    this.restingHeartRateBaseline,
    this.hrvMs,
    this.hrvBaselineMs,
    this.spo2Percent,
    this.systolic,
    this.diastolic,
  });

  bool get hasAny =>
      avgHeartRate != null ||
      restingHeartRate != null ||
      hrvMs != null ||
      spo2Percent != null ||
      systolic != null;

  Map<String, dynamic> toJson() => {
        'avgHeartRateBpm': avgHeartRate,
        'restingHeartRateBpm': restingHeartRate,
        'restingHeartRateBaselineBpm': restingHeartRateBaseline,
        'hrvMs': hrvMs?.round(),
        'hrvBaselineMs': hrvBaselineMs?.round(),
        'spo2Percent': spo2Percent,
        if (systolic != null && diastolic != null)
          'bloodPressure': '$systolic/$diastolic',
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
