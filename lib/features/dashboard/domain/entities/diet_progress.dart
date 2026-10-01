import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';

/// Maps a diet-plan meal name ("Breakfast", "Evening Snack", "Supper") to
/// the meal type the scanner logs, or null when it can't tell.
MealType? mealTypeForPlanName(String name) {
  final n = name.toLowerCase();
  if (n.contains('breakfast')) return MealType.breakfast;
  if (n.contains('lunch')) return MealType.lunch;
  if (n.contains('dinner') || n.contains('supper')) return MealType.dinner;
  if (n.contains('snack') || n.contains('tiffin')) return MealType.snack;
  return null;
}

/// A planned meal and whether something was logged for it today.
class PlannedMealStatus {
  final Meal meal;
  final MealType? type;
  final bool logged;

  const PlannedMealStatus({
    required this.meal,
    required this.type,
    required this.logged,
  });
}

/// Ticks off planned meals against today's logs. Several planned snacks
/// are matched in order against the number of snack logs.
List<PlannedMealStatus> plannedMealStatuses(
  MealPlan plan,
  List<MealLogEntry> todaysLogs,
) {
  final remaining = <MealType, int>{};
  for (final log in todaysLogs) {
    remaining[log.mealType] = (remaining[log.mealType] ?? 0) + 1;
  }
  return [
    for (final meal in plan.meals)
      () {
        final type = mealTypeForPlanName(meal.name);
        final left = type == null ? 0 : (remaining[type] ?? 0);
        // Main meals count once however many logs; snacks consume a log each.
        final logged = left > 0;
        if (logged && type == MealType.snack) remaining[type!] = left - 1;
        return PlannedMealStatus(meal: meal, type: type, logged: logged);
      }(),
  ];
}
