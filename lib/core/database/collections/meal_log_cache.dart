import 'package:isar_community/isar.dart';

part 'meal_log_cache.g.dart';

@collection
class MealLogCache {
  Id id = Isar.autoIncrement;

  @Index()
  late String mealLogId;

  @Index()
  late DateTime capturedAt;

  late String imagePath;

  late List<String> itemIds;
  late List<String> itemNames;
  late List<double> itemConfidences;
  late List<String> itemServingDescriptions;
  late List<double> itemQuantities;
  late List<String> itemUnits;

  late List<double> nutritionCalories;
  late List<double> nutritionProteinG;
  late List<double> nutritionCarbsG;
  late List<double> nutritionFatG;
  late List<double> nutritionFiberG;
  late List<double> nutritionSugarG;
  late List<double> nutritionSodiumMg;

  late double totalCalories;

  @Index()
  late int mealType; // 0: breakfast, 1: lunch, 2: dinner, 3: snack

  late bool userConfirmed;

  DateTime? createdAt;
}
