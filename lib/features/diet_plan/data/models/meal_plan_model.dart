import 'package:isar_community/isar.dart';
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

  factory MealModel.fromJson(Map<String, dynamic> json) {
    return MealModel()
      ..name = json['name'] as String?
      ..items = (json['items'] as List<dynamic>?)?.map((e) => e.toString()).toList()
      ..calories = (json['calories'] as num?)?.toInt()
      ..protein = (json['protein'] as num?)?.toInt()
      ..carbs = (json['carbs'] as num?)?.toInt()
      ..fat = (json['fat'] as num?)?.toInt();
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

  factory MealPlanModel.fromJson(Map<String, dynamic> json, String dateKey) {
    return MealPlanModel()
      ..dateKey = dateKey
      ..meals = (json['meals'] as List<dynamic>?)
          ?.map((e) => MealModel.fromJson(e as Map<String, dynamic>))
          .toList()
      ..totalCalories = (json['totalCalories'] as num?)?.toInt()
      ..totalProtein = (json['totalProtein'] as num?)?.toInt()
      ..totalCarbs = (json['totalCarbs'] as num?)?.toInt()
      ..totalFat = (json['totalFat'] as num?)?.toInt();
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
