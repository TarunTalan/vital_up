import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_log_repository.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/delete_meal_log.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/meal_log_history_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/readme_shots.dart';

class _FakeRepo implements MealLogRepository {
  final results = <Future<Either<Failure, List<MealLogEntry>>> Function()>[];
  int calls = 0;

  @override
  Future<Either<Failure, List<MealLogEntry>>> getAllMealLogs() {
    calls++;
    return results.removeAt(0)();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No Isar in widget tests: the bloc treats a failed goal read as "no goal".
class _NoIsar implements IsarService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FoodItem _food(String name) => FoodItem(
  id: name,
  name: name,
  confidenceScore: 1,
  servingDescription: '1 bowl',
  quantity: 1,
  unit: 'bowl',
);

NutritionInfo _nutrition(FoodItem per, double protein) => NutritionInfo(
  calories: 420,
  proteinG: protein,
  carbsG: 51.4,
  fatG: 12.6,
  fiberG: 6,
  sugarG: 4,
  sodiumMg: 380,
  per: per,
);

final _now = DateTime.now();

final _meals = [
  MealLogEntry(
    id: 'm1',
    capturedAt: _now.subtract(const Duration(hours: 1)),
    imagePath: '',
    items: [_food('Paneer butter masala'), _food('Jeera rice')],
    nutrition: [
      _nutrition(_food('Paneer butter masala'), 18.2),
      _nutrition(_food('Jeera rice'), 6.4),
    ],
    totalCalories: 1840,
    mealType: MealType.dinner,
    userConfirmed: true,
  ),
  MealLogEntry(
    id: 'm2',
    capturedAt: _now.subtract(const Duration(days: 4)),
    imagePath: '',
    items: [_food('Masala oats with vegetables and a boiled egg')],
    nutrition: [_nutrition(_food('Masala oats'), 14)],
    totalCalories: 320,
    mealType: MealType.breakfast,
    userConfirmed: true,
  ),
];

void main() {
  late _FakeRepo repo;

  setUp(() {
    repo = _FakeRepo();
    sl.registerFactory<MealLogBloc>(
      () => MealLogBloc(
        getMealLogHistory: GetMealLogHistory(mealLogRepository: repo),
        deleteMealLog: DeleteMealLog(mealLogRepository: repo),
        isarService: _NoIsar(),
      ),
    );
  });

  tearDown(() => sl.unregister<MealLogBloc>());

  testWidgets('shows the loader until meals arrive', (tester) async {
    final pending = Completer<Either<Failure, List<MealLogEntry>>>();
    repo.results.add(() => pending.future);
    await pumpPage(tester, const MealLogHistoryPage());
    await tester.pump();

    expect(find.byType(VitalUpLoader), findsOneWidget);
    pending.complete(Right(_meals));
    await settle(tester);
    expect(find.byType(VitalUpLoader), findsNothing);
    expect(find.text('Paneer butter masala, Jeera rice'), findsOneWidget);
  });

  testWidgets('a failed read shows its message, and retry loads', (
    tester,
  ) async {
    repo.results
      ..add(() async => const Left(CacheFailure()))
      ..add(() async => Right(_meals));
    await pumpPage(tester, const MealLogHistoryPage());
    await settle(tester);

    expect(find.byType(LoadErrorView), findsOneWidget);
    expect(find.text(const CacheFailure().message), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await settle(tester);

    expect(repo.calls, 2);
    expect(find.byType(LoadErrorView), findsNothing);
    expect(find.text('Paneer butter masala, Jeera rice'), findsOneWidget);
  });

  testWidgets('a read that throws shows the generic load error', (
    tester,
  ) async {
    repo.results.add(() async => throw Exception('disk'));
    await pumpPage(tester, const MealLogHistoryPage());
    await settle(tester);

    expect(find.text(kLoadErrorMessage), findsOneWidget);
  });

  testWidgets('no meals shows the calm empty state', (tester) async {
    repo.results.add(() async => const Right([]));
    await pumpPage(tester, const MealLogHistoryPage());
    await settle(tester);

    expect(find.text('What you log will show up here.'), findsOneWidget);
  });

  testWidgets('a meal shows the macros of every item', (tester) async {
    repo.results.add(() async => Right(_meals));
    await pumpPage(tester, const MealLogHistoryPage());
    await settle(tester);

    // The meal's calories (and its day's total).
    expect(find.text('1,840 kcal'), findsWidgets);
    // 18.2 + 6.4 g protein, summed over both items.
    expect(find.text('25 g'), findsWidgets);
    expect(find.text('Protein'), findsWidgets);
  });

  testWidgets('readme: meal history', (tester) async {
    MealLogEntry meal(
      String id,
      MealType type,
      DateTime at,
      List<(String, double, double, double, double)> items,
    ) {
      final foods = [for (final i in items) _food(i.$1)];
      return MealLogEntry(
        id: id,
        capturedAt: at,
        imagePath: '',
        items: foods,
        nutrition: [
          for (final (n, i) in items.indexed)
            NutritionInfo(
              calories: i.$2,
              proteinG: i.$3,
              carbsG: i.$4,
              fatG: i.$5,
              fiberG: 3,
              sugarG: 4,
              sodiumMg: 300,
              per: foods[n],
            ),
        ],
        totalCalories: items.fold(0.0, (s, i) => s + i.$2),
        mealType: type,
        userConfirmed: true,
      );
    }

    DateTime day(int back, int h, int m) =>
        DateTime(_now.year, _now.month, _now.day - back, h, m);
    repo.results.add(
      () async => Right([
        meal('d1', MealType.dinner, day(1, 20, 10), [
          ('Grilled paneer tikka', 360, 24, 12, 22),
          ('Mixed vegetable curry', 180, 5, 18, 9),
        ]),
        meal('s1', MealType.snack, day(1, 17, 0), [
          ('Greek yogurt with berries', 190, 14, 22, 4),
        ]),
        meal('l1', MealType.lunch, day(1, 13, 15), [
          ('Rajma chawal', 520, 18, 86, 9),
          ('Cucumber salad', 45, 2, 8, 0.5),
        ]),
        meal('b1', MealType.breakfast, day(1, 8, 30), [
          ('Masala oats', 310, 11, 48, 7),
          ('Boiled eggs', 140, 12, 1, 10),
        ]),
        meal('d2', MealType.dinner, day(2, 20, 30), [
          ('Chicken biryani', 640, 32, 72, 22),
        ]),
      ]),
    );
    await pumpReadmePage(tester, const MealLogHistoryPage());
    await captureReadmeShot(tester, 'meal_history');
  }, skip: !readmeShots);

  testWidgets('fits a small phone at the largest text size', (tester) async {
    repo.results.add(() async => Right(_meals));
    await pumpPage(
      tester,
      const MealLogHistoryPage(),
      textScale: kMaxTextScale,
    );
    await settle(tester);

    expect(
      shownTextScale(tester, find.byType(MealLogHistoryPage)),
      kMaxTextScale,
    );
    expect(takeAllExceptions(tester), isEmpty);
    // Every label, figure and button shows whole.
    expect(truncatedTexts(tester), isEmpty);
    expect(find.text('Paneer butter masala, Jeera rice'), findsOneWidget);
  });
}
