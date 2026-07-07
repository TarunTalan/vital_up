import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_recommendation.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_recommendation_repository.dart';

class GetMealRecommendation {
  final MealRecommendationRepository mealRecommendationRepository;

  GetMealRecommendation({required this.mealRecommendationRepository});

  MealRecommendation call(
    MealLogEntry entry, {
    List<dynamic>? recentActivity,
    DateTime? now,
  }) {
    return mealRecommendationRepository.recommend(
      entry,
      recentActivity: recentActivity,
      now: now ?? DateTime.now(),
    );
  }
}
