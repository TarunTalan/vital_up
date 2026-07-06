import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scan/domain/entities/meal_recommendation.dart';

abstract class MealRecommendationRepository {
  MealRecommendation recommend(
    MealLogEntry entry, {
    List<dynamic>? recentActivity,
    required DateTime now,
  });
}
