import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/collections/sleep_log_cache.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
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

  /// The signed-in user's profile (cache-first), so details edited after
  /// onboarding reach Vita. Onboarding answers are only the fallback.
  final ProfileRepository? _profiles;

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
    ProfileRepository? profiles,
  }) : _profiles = profiles;

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
    final healthSteps = results[9] as int?;

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
      sleepLastNightFromHealthConnect: sleep?.fromHealthConnect ?? false,
      loggedSleepLastNightHours: sleep?.loggedLastNight,
      loggedSleepAvgHours: sleep?.loggedAverage,
      loggedSleepNights: sleep?.loggedNights ?? 0,
      waterTodayMl: water?.todayMl,
      waterGoalMl: _water.getDailyGoal(),
      tracksWater: water?.tracks ?? false,
      screenTimeTodayMinutes: results[3] as int?,
      stepsToday: healthSteps ?? activity?.stepsToday,
      stepsFromHealthConnect: healthSteps != null,
      workoutStepsToday: activity?.stepsToday,
      workoutsThisWeek: activity?.workouts ?? 0,
      distanceThisWeekKm: activity?.distanceKm ?? 0,
      activeMinutesThisWeek: activity?.minutes ?? 0,
      importedWorkoutsThisWeek: activity?.importedWorkouts ?? 0,
      importedDistanceThisWeekKm: activity?.importedDistanceKm ?? 0,
      importedActiveMinutesThisWeek: activity?.importedMinutes ?? 0,
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
    final week = entries
        .where((e) => !e.capturedAt.isBefore(weekStart))
        .toList();
    final todays = week.where((e) => !e.capturedAt.isBefore(today)).toList();

    final perDay = <DateTime, double>{};
    for (final e in week) {
      final day = DateTime(
        e.capturedAt.year,
        e.capturedAt.month,
        e.capturedAt.day,
      );
      perDay[day] = (perDay[day] ?? 0) + e.totalCalories;
    }
    final avg = perDay.isEmpty
        ? null
        : (perDay.values.reduce((a, b) => a + b) / perDay.length).round();

    return _Meals(
      today: todays.length,
      caloriesToday: todays
          .fold<double>(0, (s, e) => s + e.totalCalories)
          .round(),
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

    // Saved entries are manual or the phone's estimate, never Health Connect.
    final loggedLastNight =
        recent.isNotEmpty &&
            recent.first.endTime.isAfter(now.subtract(const Duration(hours: 24)))
        ? recent.first.durationMinutes / 60
        : null;
    final logged = recent.map((l) => l.durationMinutes / 60).toList();
    double? average(List<double> hours) =>
        hours.isEmpty ? null : hours.reduce((a, b) => a + b) / hours.length;

    final healthLastNight = await _vitals.readSleepLastNightHours();
    final lastNight = healthLastNight ?? loggedLastNight;
    final hours = [...logged];
    if (lastNight != null && recent.isEmpty) hours.add(lastNight);
    return _Sleep(
      lastNight: lastNight,
      average: average(hours),
      nights: hours.length,
      fromHealthConnect: healthLastNight != null,
      loggedLastNight: loggedLastNight,
      loggedAverage: average(logged),
      loggedNights: logged.length,
    );
  }

  Future<_Water> _waterData(DateTime today, DateTime weekStart) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const _Water(todayMl: null, tracks: false);
    final logs = await _isar.isar.waterLogCaches.where().findAll();
    final mine = logs.where(
      (l) => l.userId == userId && !l.timestamp.isBefore(weekStart),
    );
    final todayMl = mine
        .where((l) => !l.timestamp.isBefore(today))
        .fold<int>(0, (s, l) => s + l.amountMl);
    return _Water(todayMl: todayMl, tracks: mine.isNotEmpty);
  }

  Future<int?> _screenMinutes() async {
    if (!await _screenTime.hasPermission()) return null;
    final stats = await _screenTime.getUsageStats();
    if (stats.isEmpty) return null;
    return stats
        .fold<Duration>(Duration.zero, (s, a) => s + a.usageDuration)
        .inMinutes;
  }

  Future<_Activity> _activityData(DateTime today, DateTime weekStart) async {
    final history = await _activity();
    final week = history
        .map((h) => h.session)
        .where((s) => !s.startTime.isBefore(weekStart))
        .toList();
    final imported = week
        .where((s) => s.id.startsWith(HealthImportService.idPrefix))
        .toList();
    final todays = week.where(
      (s) =>
          !s.startTime.isBefore(today) &&
          s.stepCountReliable &&
          !s.id.startsWith(HealthImportService.idPrefix),
    );
    final steps = todays.fold<int>(0, (sum, s) => sum + s.steps);
    double km(List<ActivitySession> s) =>
        s.fold<double>(0, (sum, a) => sum + a.totalDistanceMeters) / 1000;
    int minutes(List<ActivitySession> s) =>
        s.fold<int>(0, (sum, a) => sum + a.totalDurationSeconds) ~/ 60;
    return _Activity(
      workouts: week.length,
      distanceKm: km(week),
      minutes: minutes(week),
      stepsToday: steps > 0 ? steps : null,
      importedWorkouts: imported.length,
      importedDistanceKm: km(imported),
      importedMinutes: minutes(imported),
    );
  }

  Future<ProfileSnapshot> _profile() async {
    final o = _onboarding;
    final values = await Future.wait([
      o.getDob(), o.getGender(), o.getWeight(), o.getWeightUnit(), // 0-3
      o.getHeight(), o.getHeightUnit(), o.getGoalType(), // 4-6
      o.getTargetWeight(),
      o.getTargetWeightUnit(),
      o.getDietaryPreference(), // 7-9
      o.getHealthConditions(), o.getAllergies(), o.getMedicines(), // 10-12
      o.getSmokes(), o.getActivity(), // 13-14
      o.getBloodPressureTop(), o.getBloodPressureBottom(), // 15-16
    ]);

    final cache = await _profileCache();
    final p = await _currentProfile();
    // The saved profile wins; onboarding answers fill what it lacks.
    String pick(String? saved, String onboarding) =>
        saved != null && saved.trim().isNotEmpty ? saved : onboarding;

    return ProfileSnapshot(
      age: ageFromDob(pick(p?.dob, values[0])),
      gender: meaningfulOrNull(pick(p?.gender, values[1])),
      weightKg:
          cache?.weightKg ??
          _kg(pick(p?.weight, values[2]), pick(p?.weightUnit, values[3])),
      heightCm: _cm(pick(p?.height, values[4]), pick(p?.heightUnit, values[5])),
      goalType: meaningfulOrNull(values[6]),
      targetWeightKg: cache?.targetWeightKg ?? _kg(values[7], values[8]),
      dietaryPreference: meaningfulOrNull(values[9]),
      healthConditions: meaningfulOrNull(pick(p?.healthConditions, values[10])),
      allergies: meaningfulOrNull(pick(p?.allergies, values[11])),
      medicines: meaningfulOrNull(pick(p?.medicines, values[12])),
      smokes: meaningfulOrNull(pick(p?.smokes, values[13])),
      activityLevel: meaningfulOrNull(pick(p?.activity, values[14])),
      bloodPressureTop: int.tryParse(
        pick(p?.bloodPressureTop, values[15]).trim(),
      ),
      bloodPressureBottom: int.tryParse(
        pick(p?.bloodPressureBottom, values[16]).trim(),
      ),
    );
  }

  Future<ProfileEntity?> _currentProfile() async {
    final profiles = _profiles;
    if (profiles == null) return null;
    try {
      final result = await profiles.getProfile().withLoadTimeout();
      return result.fold((_) => null, (p) => p);
    } catch (e) {
      debugPrint('Profile for Vita unavailable: $e');
      return null;
    }
  }

  /// This account's Isar profile mirror (never another account's row).
  Future<UserProfileCache?> _profileCache() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return _isar.isar.userProfileCaches.getBySupabaseId(userId);
  }

  Future<int?> _calorieGoal() async {
    final cache = await _profileCache();
    return cache?.dailyCalorieGoal ??
        int.tryParse(await _onboarding.getCalorieGoal());
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

  /// Profile and onboarding store DOB as ddMMyyyy (older builds wrote
  /// dd/MM/yyyy, so separators are dropped first).
  @visibleForTesting
  static int? ageFromDob(String dob) =>
      ProfileRules.ageFromDob(dob.replaceAll(RegExp(r'[\s/.\-]'), ''));

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
  final bool fromHealthConnect;
  final double? loggedLastNight, loggedAverage;
  final int loggedNights;
  const _Sleep({
    this.lastNight,
    this.average,
    required this.nights,
    required this.fromHealthConnect,
    this.loggedLastNight,
    this.loggedAverage,
    required this.loggedNights,
  });
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
  final int importedWorkouts, importedMinutes;
  final double importedDistanceKm;
  const _Activity({
    required this.workouts,
    required this.distanceKm,
    required this.minutes,
    this.stepsToday,
    required this.importedWorkouts,
    required this.importedDistanceKm,
    required this.importedMinutes,
  });
}
