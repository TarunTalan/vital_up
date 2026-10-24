import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/generate_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/set_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/diet_plan/presentation/widgets/meal_alternatives.dart';
import 'package:vital_up/core/theme/app_theme.dart';

import '../../helpers/pump_app.dart';

const _upma = MealOption(
  items: ['1 Bowl Upma', '1 Glass Chaas'],
  calories: 380,
  protein: 14,
  carbs: 55,
  fat: 10,
);
const _dosa = MealOption(
  items: ['2 Moong Dal Dosa'],
  calories: 430,
  protein: 22,
  carbs: 50,
  fat: 12,
);

const _breakfast = Meal(
  name: 'Breakfast',
  items: ['2 Besan Chilla', '1 Cup Curd'],
  calories: 400,
  protein: 20,
  carbs: 45,
  fat: 12,
  alternatives: [_upma, _dosa],
);
const _lunch = Meal(
  name: 'Lunch',
  items: ['2 Roti', '1 Bowl Dal'],
  calories: 600,
  protein: 25,
  carbs: 80,
  fat: 15,
);
// The plan's own totals are a little off the sum of its meals (as AI
// totals can be): a swap moves them by the difference, keeping that gap.
const _plan = MealPlan(
  meals: [_breakfast, _lunch],
  totalCalories: 1010,
  totalProtein: 45,
  totalCarbs: 125,
  totalFat: 27,
);

class _FakePlans implements DietPlanRepository {
  MealPlan? active = _plan;
  Map<String, dynamic> preferences = {'dietaryType': 'Vegetarian'};
  Map<String, dynamic>? savedPreferences;
  bool failSave = false;

  @override
  Future<MealPlan?> getActiveMealPlan() async => active;

  @override
  Future<Map<String, dynamic>> getActivePlanPreferences() async => preferences;

  @override
  Future<void> setActiveMealPlan(
    MealPlan plan, {
    Map<String, dynamic> preferences = const {},
  }) async {
    if (failSave) throw StateError('disk full');
    active = plan;
    savedPreferences = preferences;
  }

  @override
  Future<ApiResult<MealPlan>> generateMealPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  }) async => const ApiSuccess(_plan);
}

DietPlanCubit _cubit(_FakePlans repo) => DietPlanCubit(
  generateMealPlan: GenerateMealPlan(repo),
  getActiveMealPlan: GetActiveMealPlan(repo),
  setActiveMealPlan: SetActiveMealPlan(repo),
);

void main() {
  group('swapping a dish', () {
    test('the chosen dish moves in, the old one becomes an option', () {
      final swapped = _breakfast.withAlternative(1);
      expect(swapped.items, _dosa.items);
      expect(swapped.calories, 430);
      expect(swapped.alternatives, [_upma, _breakfast.dish]);
      // Swapping back restores the meal exactly.
      expect(swapped.withAlternative(1), _breakfast);
    });

    test('plan totals move by the difference between the dishes', () {
      final swapped = _plan.withAlternative(0, 0);
      expect(swapped.meals[0].items, _upma.items);
      expect(swapped.meals[1], _lunch);
      expect(swapped.totalCalories, 1010 - 400 + 380);
      expect(swapped.totalProtein, 45 - 20 + 14);
      expect(swapped.totalCarbs, 125 - 45 + 55);
      expect(swapped.totalFat, 27 - 12 + 10);
    });
  });

  group('stored plans', () {
    test('alternatives are read cleaned, at most two, empty ones dropped', () {
      final model = MealPlanModel.fromJson({
        'meals': [
          {
            'name': 'Breakfast',
            'items': ['Poha'],
            'calories': 350,
            'alternatives': [
              {'items': []},
              'junk',
              {
                'items': ['  Upma\n', null],
                'calories': '360',
                'protein': -4,
              },
              {
                'items': ['Idli'],
                'calories': 1e9,
              },
              {
                'items': ['Dosa'],
                'calories': 340,
              },
            ],
          },
        ],
      }, 'k');
      final alts = model.meals!.single.alternatives!;
      expect(alts.map((a) => a.items), [
        ['Upma'],
        ['Idli'],
      ]);
      expect(alts[0].calories, 360);
      expect(alts[0].protein, 0);
      expect(alts[1].calories, MealModel.maxCalories);
    });

    test('a plan from before alternatives loads with none', () {
      final plan = MealPlanModel.fromJson({
        'meals': [
          {
            'name': 'Lunch',
            'items': ['Dal'],
            'calories': 500,
          },
        ],
      }, 'k').toEntity();
      expect(plan.meals.single.alternatives, isEmpty);
    });

    test('alternatives survive saving, backup JSON and loading', () {
      final model = MealPlanModel.fromEntity(_plan, 'k');
      final restored = MealPlanModel.fromJson(model.toJson(), 'k').toEntity();
      expect(restored, _plan);
      expect(model.toEntity(), _plan);
    });
  });

  group('DietPlanCubit.chooseAlternative', () {
    test('a new plan swaps on screen only', () async {
      final repo = _FakePlans()..active = null;
      final cubit = _cubit(repo);
      cubit.emit(const DietPlanLoaded(_plan));
      expect(await cubit.chooseAlternative(0, 1), isTrue);
      expect(
        (cubit.state as DietPlanLoaded).mealPlan.meals[0].items,
        _dosa.items,
      );
      expect(repo.active, isNull);
      await cubit.close();
    });

    test('the active plan is saved with its preferences kept', () async {
      final repo = _FakePlans();
      final cubit = _cubit(repo);
      await cubit.loadActiveMealPlan();
      expect(await cubit.chooseAlternative(0, 0, save: true), isTrue);
      expect(repo.active!.meals[0].items, _upma.items);
      expect(repo.savedPreferences, {'dietaryType': 'Vegetarian'});
      await cubit.close();
    });

    test('a failed save puts the dish back', () async {
      final repo = _FakePlans()..failSave = true;
      final cubit = _cubit(repo);
      await cubit.loadActiveMealPlan();
      expect(await cubit.chooseAlternative(0, 0, save: true), isFalse);
      expect((cubit.state as DietPlanLoaded).mealPlan, _plan);
      await cubit.close();
    });

    test('out of range does nothing', () async {
      final cubit = _cubit(_FakePlans());
      await cubit.loadActiveMealPlan();
      expect(await cubit.chooseAlternative(1, 0), isFalse); // lunch has none
      expect(await cubit.chooseAlternative(5, 0), isFalse);
      expect((cubit.state as DietPlanLoaded).mealPlan, _plan);
      await cubit.close();
    });
  });

  testWidgets('options sheet fits the largest text, light and dark', (
    tester,
  ) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      for (final scale in [1.0, kMaxTextScale]) {
        int? picked = -1;
        await pumpPage(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: MealAlternativesLink(
                  meal: _breakfast,
                  onTap: () async {
                    picked = await showMealAlternativesSheet(
                      context,
                      _breakfast,
                    );
                  },
                ),
              ),
            ),
          ),
          textScale: scale,
          theme: theme,
        );
        expect(find.text('2 other options'), findsOneWidget);
        await tester.tap(find.text('2 other options'));
        await tester.pumpAndSettle();
        expect(find.text('In your plan'), findsOneWidget);
        // Summary parts keep their words together (no-break spaces).
        expect(find.textContaining('20\u00a0kcal\u00a0less'), findsOneWidget);
        expect(find.text('Use'), findsNWidgets(2));
        expect(takeAllExceptions(tester), isEmpty);
        expect(truncatedTexts(tester), isEmpty, reason: 'text $scale');

        await tester.ensureVisible(find.text('Use').last);
        await tester.tap(find.text('Use').last);
        await tester.pumpAndSettle();
        expect(picked, 1);
      }
    }
  });

  testWidgets('a meal without alternatives shows no link', (tester) async {
    await pumpPage(
      tester,
      Scaffold(
        body: MealAlternativesLink(meal: _lunch, onTap: () {}),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}
