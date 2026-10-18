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

    Finder pill(String text) => find.text(text, findRichText: true);
    expect(pill('Cals: 1840'), findsOneWidget);
    // 18.2 + 6.4 g protein, summed over both items.
    expect(pill('P: 25g'), findsOneWidget);
  });

  testWidgets(
    'fits a small phone at the largest text size',
    (tester) async {
      repo.results.add(() async => Right(_meals));
      await pumpPage(
        tester,
        const MealLogHistoryPage(),
        textScale: kMaxTextScale,
      );
      await settle(tester);

      expect(shownTextScale(tester, find.byType(MealLogHistoryPage)), 2.0);
      expect(takeAllExceptions(tester), isEmpty);
      expect(find.text('Paneer butter masala, Jeera rice'), findsOneWidget);
    },
  );
}
