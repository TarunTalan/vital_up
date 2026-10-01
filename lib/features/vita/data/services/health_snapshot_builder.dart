import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/collections/sleep_log_cache.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/vita/data/services/health_vitals_service.dart';
import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';

/// Collects a [HealthSnapshot] from every on-device source. Each source is
/// read independently; one failing (no permission, empty DB) only leaves its
/// fields empty.
class HealthSnapshotBuilder {
  final GetMealLogHistory _mealHistory;
  final IsarService _isar;
  final WaterIntakeService _water;
  final ScreenTimeService _screenTime;
  final GetActivityHistory _activity;
  final OnboardingDataStore _onboarding;
  final GetActiveMealPlan _activePlan;
  final HealthVitalsService _vitals;
  final SupabaseClient _supabase;

  HealthSnapshotBuilder({
    required this._mealHistory,
    required this._isar,
    required this._water,
    required this._screenTime,
    required this._activity,
    required this._onboarding,
    required this._activePlan,
    required this._vitals,
    required this._supabase,
  });

  Future<HealthSnapshot> build() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    final results = await Future.wait<Object?>([
      _safe('meals', () => _meals(today, weekStart)),
      _safe('sleep', () => _sleep(now)),
      _safe('water', () => _waterData(today, weekStart)),
      _safe<int?>('screen', _screenMinutes),
      _safe('activity', () => _activityData(today, weekStart)),
      _safe('profile', _profile),
      _safe<int?>('calorieGoal', _calorieGoal),
      _safe('plan', _planLines),
      _safe('vitals', _vitals.readVitals),
      _safe<int?>('steps', _vitals.readStepsToday),
    ]);

    final meals = results[0] as _Meals?;
    final sleep = results[1] as _Sleep?;
    final water = results[2] as _Water?;
    final activity = results[4] as _Activity?;

    return HealthSnapshot(
      takenAt: now,
      profile: results[5] as ProfileSnapshot? ?? const ProfileSnapshot(),
      mealsToday: meals?.today ?? 0,
      caloriesToday: meals?.caloriesToday ?? 0,
      calorieGoal: results[6] as int?,
      mealsThisWeek: meals?.week ?? 0,
      daysWithMealsThisWeek: meals?.days ?? 0,
      avgCaloriesPerDay: meals?.avgPerDay,
      todayMealSummaries: meals?.summaries ?? const [],
      sleepLastNightHours: sleep?.lastNight,
      sleepAvgHours: sleep?.average,
      sleepNightsLogged: sleep?.nights ?? 0,
      waterTodayMl: water?.todayMl,
      waterGoalMl: _water.getDailyGoal(),
      tracksWater: water?.tracks ?? false,
      screenTimeTodayMinutes: results[3] as int?,
      stepsToday: results[9] as int? ?? activity?.stepsToday,
      workoutsThisWeek: activity?.workouts ?? 0,
      distanceThisWeekKm: activity?.distanceKm ?? 0,
      activeMinutesThisWeek: activity?.minutes ?? 0,
      vitals: results[8] as VitalsSnapshot? ?? const VitalsSnapshot(),
      dietPlanMeals: results[7] as List<String>? ?? const [],
    );
  }

  Future<T?> _safe<T>(String name, Future<T> Function() read) async {
    try {
      return await read().timeout(kSourceTimeout);
    } catch (e) {
      debugPrint('Vita snapshot: $name unavailable ($e)');
      return null;
    }
  }

  Future<_Meals> _meals(DateTime today, DateTime weekStart) async {
    final result = await _mealHistory.callAll();
    final entries = result.fold<List<MealLogEntry>>((_) => const [], (e) => e);
    final week = entries.where((e) => !e.capturedAt.isBefore(weekStart)).toList();
    final todays = week.where((e) => !e.capturedAt.isBefore(today)).toList();

    final perDay = <DateTime, double>{};
    for (final e in week) {
      final day = DateTime(e.capturedAt.year, e.capturedAt.month, e.capturedAt.day);
      perDay[day] = (perDay[day] ?? 0) + e.totalCalories;
    }
    final avg = perDay.isEmpty
        ? null
        : (perDay.values.reduce((a, b) => a + b) / perDay.length).round();

    return _Meals(
      today: todays.length,
      caloriesToday: todays.fold<double>(0, (s, e) => s + e.totalCalories).round(),
      week: week.length,
      days: perDay.length,
      avgPerDay: avg,
      summaries: [
        for (final e in todays)
          '${e.mealType.name} · ${e.totalCalories.round()} kcal · '
              '${e.items.map((i) => i.name).take(4).join(', ')}',
      ],
    );
  }

  Future<_Sleep> _sleep(DateTime now) async {
    final logs = await _isar.isar.sleepLogCaches.where().findAll();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recent = logs.where((l) => l.endTime.isAfter(weekAgo)).toList()
      ..sort((a, b) => b.endTime.compareTo(a.endTime));

    var lastNight = await _vitals.readSleepLastNightHours();
    if (lastNight == null && recent.isNotEmpty &&
        recent.first.endTime.isAfter(now.subtract(const Duration(hours: 24)))) {
      lastNight = recent.first.durationMinutes / 60;
    }

    final hours = recent.map((l) => l.durationMinutes / 60).toList();
    if (lastNight != null && recent.isEmpty) hours.add(lastNight);
    return _Sleep(
      lastNight: lastNight,
      average: hours.isEmpty ? null : hours.reduce((a, b) => a + b) / hours.length,
      nights: hours.length,
    );
  }

  Future<_Water> _waterData(DateTime today, DateTime weekStart) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const _Water(todayMl: null, tracks: false);
    final logs = await _isar.isar.waterLogCaches.where().findAll();
    final mine = logs.where((l) => l.userId == userId && !l.timestamp.isBefore(weekStart));
    final todayMl = mine
        .where((l) => !l.timestamp.isBefore(today))
        .fold<int>(0, (s, l) => s + l.amountMl);
    return _Water(todayMl: todayMl, tracks: mine.isNotEmpty);
  }

  Future<int?> _screenMinutes() async {
    if (!await _screenTime.hasPermission()) return null;
    final stats = await _screenTime.getUsageStats();
    if (stats.isEmpty) return null;
    return stats.fold<Duration>(Duration.zero, (s, a) => s + a.usageDuration).inMinutes;
  }

  Future<_Activity> _activityData(DateTime today, DateTime weekStart) async {
    final history = await _activity();
    final week = history
        .map((h) => h.session)
        .where((s) => !s.startTime.isBefore(weekStart))
        .toList();
    final todays = week.where((s) => !s.startTime.isBefore(today) && s.stepCountReliable);
    final steps = todays.fold<int>(0, (sum, s) => sum + s.steps);
    return _Activity(
      workouts: week.length,
      distanceKm: week.fold<double>(0, (s, a) => s + a.totalDistanceMeters) / 1000,
      minutes: week.fold<int>(0, (s, a) => s + a.totalDurationSeconds) ~/ 60,
      stepsToday: steps > 0 ? steps : null,
    );
  }

  Future<ProfileSnapshot> _profile() async {
    final o = _onboarding;
    final values = await Future.wait([
      o.getDob(), o.getGender(), o.getWeight(), o.getWeightUnit(), // 0-3
      o.getHeight(), o.getHeightUnit(), o.getGoalType(), // 4-6
      o.getTargetWeight(), o.getTargetWeightUnit(), o.getDietaryPreference(), // 7-9
      o.getHealthConditions(), o.getAllergies(), o.getMedicines(), // 10-12
      o.getSmokes(), o.getActivity(), // 13-14
      o.getBloodPressureTop(), o.getBloodPressureBottom(), // 15-16
    ]);

    final cache = await _isar.isar.userProfileCaches.where().findFirst();

    return ProfileSnapshot(
      age: _age(values[0]),
      gender: meaningfulOrNull(values[1]),
      weightKg: cache?.weightKg ?? _kg(values[2], values[3]),
      heightCm: _cm(values[4], values[5]),
      goalType: meaningfulOrNull(values[6]),
      targetWeightKg: cache?.targetWeightKg ?? _kg(values[7], values[8]),
      dietaryPreference: meaningfulOrNull(values[9]),
      healthConditions: meaningfulOrNull(values[10]),
      allergies: meaningfulOrNull(values[11]),
      medicines: meaningfulOrNull(values[12]),
      smokes: meaningfulOrNull(values[13]),
      activityLevel: meaningfulOrNull(values[14]),
      bloodPressureTop: int.tryParse(values[15].trim()),
      bloodPressureBottom: int.tryParse(values[16].trim()),
    );
  }

  Future<int?> _calorieGoal() async {
    final cache = await _isar.isar.userProfileCaches.where().findFirst();
    return cache?.dailyCalorieGoal ?? int.tryParse(await _onboarding.getCalorieGoal());
  }

  Future<List<String>> _planLines() async {
    final plan = await _activePlan();
    return plan == null ? const [] : planLines(plan);
  }

  /// One compact line per meal, as sent to Vita.
  static List<String> planLines(MealPlan plan) => [
        for (final m in plan.meals)
          '${m.name} · ${m.calories} kcal · ${m.items.join(', ')}',
      ];

  /// Onboarding stores DOB as DD/MM/YYYY.
  static int? _age(String dob) {
    final parts = dob.split('/').map((p) => int.tryParse(p.trim())).toList();
    if (parts.length != 3 || parts.any((p) => p == null)) return null;
    var (day, month, year) = (parts[0]!, parts[1]!, parts[2]!);
    if (month > 12 && day <= 12) (day, month) = (month, day);
    if (year < 1900 || month < 1 || month > 12) return null;
    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) age--;
    return age >= 0 && age < 130 ? age : null;
  }

  static double? _kg(String value, String unit) {
    final v = double.tryParse(value.trim());
    if (v == null || v <= 0) return null;
    return unit.toLowerCase().startsWith('lb') ? v * 0.4536 : v;
  }

  /// Onboarding stores ft heights as "5-7" (feet-inches).
  static double? _cm(String value, String unit) {
    if (unit.toLowerCase() == 'ft') {
      final parts = value.split('-');
      final feet = int.tryParse(parts.first.trim());
      if (feet == null) return null;
      final inches = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
      return (feet * 12 + inches) * 2.54;
    }
    final v = double.tryParse(value.trim());
    return v == null || v <= 0 ? null : v;
  }
}

class _Meals {
  final int today, caloriesToday, week, days;
  final int? avgPerDay;
  final List<String> summaries;
  const _Meals({
    required this.today,
    required this.caloriesToday,
    required this.week,
    required this.days,
    required this.avgPerDay,
    required this.summaries,
  });
}

class _Sleep {
  final double? lastNight, average;
  final int nights;
  const _Sleep({this.lastNight, this.average, required this.nights});
}

class _Water {
  final int? todayMl;
  final bool tracks;
  const _Water({required this.todayMl, required this.tracks});
}

class _Activity {
  final int workouts, minutes;
  final double distanceKm;
  final int? stepsToday;
  const _Activity({
    required this.workouts,
    required this.distanceKm,
    required this.minutes,
    this.stepsToday,
  });
}
