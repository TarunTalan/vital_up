import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/food_scanner/data/datasources/meal_log_local_data_source_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/meal_log_repository_impl.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

import 'support/fake_backend.dart';
import 'support/test_device.dart';

/// Entries made just before and just after local midnight land on the
/// right day in what Home and the trend pages read, including entries
/// pulled from the server (stored in UTC).

const _user = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

class _Unused implements SleepService, VitaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoPlan implements DietPlanRepository {
  @override
  Future<MealPlan?> getActiveMealPlan() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _idli = FoodItem(
  id: 'f',
  name: 'Idli',
  confidenceScore: 1,
  servingDescription: '2 pieces',
  quantity: 2,
  unit: 'piece',
);

MealLogEntry _meal(String id, DateTime at, double calories) => MealLogEntry(
  id: id,
  capturedAt: at,
  imagePath: '',
  items: const [_idli],
  nutrition: [
    NutritionInfo(
      calories: calories,
      proteinG: 4,
      carbsG: 30,
      fatG: 1,
      fiberG: 2,
      sugarG: 1,
      sodiumMg: 200,
      per: _idli,
    ),
  ],
  totalCalories: calories,
  mealType: MealType.snack,
  userConfirmed: true,
);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = await initIsarForTests();

  late FakeBackend backend;
  late TestDevice phone;
  late MealLogLocalDataSourceImpl meals;
  late TrendsService trends;
  late DateTime today;
  late DateTime lastMoment;

  setUp(() async {
    if (skip != null) return;
    backend = FakeBackend();
    phone = await TestDevice.create(backend);
    await phone.signIn(_user);
    meals = MealLogLocalDataSourceImpl(
      isarService: phone.isarService,
      uuid: const Uuid(),
    );
    trends = TrendsService(
      phone.water,
      _Unused(),
      _Unused(),
      GetMealLogHistory(
        mealLogRepository: MealLogRepositoryImpl(
          localDataSource: meals,
          logger: Logger(level: Level.off),
        ),
      ),
      GetActiveMealPlan(_NoPlan()),
    );
    today = startOfDay(DateTime.now());
    // The last microsecond of yesterday.
    lastMoment = today.subtract(const Duration(microseconds: 1));
  });

  tearDown(() async {
    if (skip == null) await phone.dispose();
  });

  Future<void> putWater(DateTime at, int ml) => phone.isar.writeTxn(
    () => phone.isar.waterLogCaches.put(
      WaterLogCache()
        ..userId = _user
        ..amountMl = ml
        ..timestamp = at,
    ),
  );

  test('water either side of midnight counts for its own day', () async {
    await putWater(lastMoment, 300);
    await putWater(today, 200);

    final todayLogs = await phone.water.getTodayLogs(_user);
    expect(todayLogs.map((l) => l.amountMl), [200]);

    final week = (await trends.water(_user, TrendRange.week)).series.points;
    expect(week.last.day, today);
    expect(week.last.value, 200);
    expect(week[week.length - 2].day, previousDay(today));
    expect(week[week.length - 2].value, 300);
  }, skip: skip);

  test('meals either side of midnight count for their own day', () async {
    await meals.saveMealLog(_meal('late', lastMoment, 450));
    await meals.saveMealLog(
      _meal('early', today.add(const Duration(seconds: 30)), 120),
    );

    expect((await meals.getMealLogsForDate(today)).map((m) => m.id), ['early']);
    expect(
      (await meals.getMealLogsForDate(previousDay(today))).map((m) => m.id),
      ['late'],
    );
    final week = (await trends.calories(TrendRange.week)).series.points;
    expect(week.last.value, 120);
    expect(week[week.length - 2].value, 450);
  }, skip: skip);

  test('weights either side of midnight are two days on the chart', () async {
    expect(
      await phone.weight.add(
        70.4,
        at: today.subtract(const Duration(minutes: 2)),
      ),
      isNull,
    );
    expect(
      await phone.weight.add(70.1, at: today.add(const Duration(minutes: 2))),
      isNull,
    );

    final week = (await phone.weight.trend(TrendRange.week)).series.points;
    expect(week.last.value, 70.1);
    expect(week[week.length - 2].value, 70.4);
  }, skip: skip);

  test('entries pulled from the server (UTC) land on the local day', () async {
    // Logged on another phone a second either side of local midnight; the
    // server stores and returns UTC.
    for (final (id, at, ml) in [
      ('w-late', today.subtract(const Duration(seconds: 1)), 350),
      ('w-early', today.add(const Duration(seconds: 1)), 150),
    ]) {
      (backend.tables['water_logs'] ??= {})[id] = {
        'id': id,
        'user_id': _user,
        'amount_ml': ml,
        'logged_at': at.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_at': null,
      };
    }
    await phone.sync.sync(force: true);

    expect((await phone.water.getTodayLogs(_user)).map((l) => l.amountMl), [
      150,
    ]);
    final week = (await trends.water(_user, TrendRange.week)).series.points;
    expect(week[week.length - 2].value, 350);
    expect(week.last.value, 150);
  }, skip: skip);
}
