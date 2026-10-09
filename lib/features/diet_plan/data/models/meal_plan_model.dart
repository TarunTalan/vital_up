import 'package:isar_community/isar.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import '../../domain/entities/meal_plan.dart';

part 'meal_plan_model.g.dart';

@embedded
class MealModel {
  String? name;
  List<String>? items;
  int? calories;
  int? protein;
  int? carbs;
  int? fat;

  MealModel();

  /// Most items one meal can list; anything beyond is AI noise.
  static const maxItems = 20;

  /// Calories / grams allowed in one meal.
  static const maxCalories = 5000;
  static const maxGrams = 1000;

  /// Parses an AI (or backup) meal: clean single-line text, at most
  /// [maxItems] items, numbers clamped to sane ranges.
  factory MealModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return MealModel()
      ..name = sanitizeOptional(json['name']?.toString(), maxLength: InputLimits.shortText)
      ..items = rawItems is List
          ? [
              for (final e in rawItems)
                if (e != null && sanitizeText(e.toString(), maxLength: InputLimits.shortText * 2).isNotEmpty)
                  sanitizeText(e.toString(), maxLength: InputLimits.shortText * 2),
            ].take(maxItems).toList()
          : null
      ..calories = saneInt(json['calories'], maxCalories)
      ..protein = saneInt(json['protein'], maxGrams)
      ..carbs = saneInt(json['carbs'], maxGrams)
      ..fat = saneInt(json['fat'], maxGrams);
  }

  /// A whole number in [0, max] from untrusted JSON (num or numeric
  /// string); null when missing or not a finite number.
  static int? saneInt(Object? raw, int max) {
    final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (value == null || !value.isFinite) return null;
    if (value <= 0) return 0;
    return value > max ? max : value.round();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  Meal toEntity() {
    return Meal(
      name: name ?? '',
      items: items ?? [],
      calories: calories ?? 0,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fat: fat ?? 0,
    );
  }

  factory MealModel.fromEntity(Meal meal) {
    return MealModel()
      ..name = meal.name
      ..items = meal.items
      ..calories = meal.calories
      ..protein = meal.protein
      ..carbs = meal.carbs
      ..fat = meal.fat;
  }
}

@collection
class MealPlanModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String dateKey;

  List<MealModel>? meals;
  int? totalCalories;
  int? totalProtein;
  int? totalCarbs;
  int? totalFat;

  MealPlanModel();

  /// Most meals a day plan can hold (the app offers 2 to 6).
  static const maxMeals = 8;

  /// Parses an AI (or backup) plan. Malformed meals are skipped, values are
  /// clamped, and missing totals are summed from the meals.
  factory MealPlanModel.fromJson(Map<String, dynamic> json, String dateKey) {
    final rawMeals = json['meals'];
    final meals = rawMeals is List
        ? rawMeals
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => MealModel.fromJson(Map<String, dynamic>.from(e)))
            .where((m) => (m.name ?? '').isNotEmpty || (m.items ?? const []).isNotEmpty)
            .take(maxMeals)
            .toList()
        : null;
    int? total(String key, int Function(MealModel m) pick, int max) {
      final given = MealModel.saneInt(json[key], max);
      if (given != null && given > 0) return given;
      if (meals == null || meals.isEmpty) return given;
      final sum = meals.fold<int>(0, (s, m) => s + pick(m));
      return sum > max ? max : sum;
    }

    return MealPlanModel()
      ..dateKey = dateKey
      ..meals = meals
      ..totalCalories = total('totalCalories', (m) => m.calories ?? 0, InputLimits.caloriesMax)
      ..totalProtein = total('totalProtein', (m) => m.protein ?? 0, 2000)
      ..totalCarbs = total('totalCarbs', (m) => m.carbs ?? 0, 2000)
      ..totalFat = total('totalFat', (m) => m.fat ?? 0, 2000);
  }

  Map<String, dynamic> toJson() {
    return {
      'meals': meals?.map((e) => e.toJson()).toList(),
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
    };
  }

  MealPlan toEntity() {
    return MealPlan(
      meals: meals?.map((e) => e.toEntity()).toList() ?? [],
      totalCalories: totalCalories ?? 0,
      totalProtein: totalProtein ?? 0,
      totalCarbs: totalCarbs ?? 0,
      totalFat: totalFat ?? 0,
    );
  }

  factory MealPlanModel.fromEntity(MealPlan plan, String dateKey) {
    return MealPlanModel()
      ..dateKey = dateKey
      ..meals = plan.meals.map((e) => MealModel.fromEntity(e)).toList()
      ..totalCalories = plan.totalCalories
      ..totalProtein = plan.totalProtein
      ..totalCarbs = plan.totalCarbs
      ..totalFat = plan.totalFat;
  }
}
