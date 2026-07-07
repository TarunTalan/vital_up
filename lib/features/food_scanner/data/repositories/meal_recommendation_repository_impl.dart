import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_recommendation.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_recommendation_repository.dart';

class MealRecommendationRepositoryImpl implements MealRecommendationRepository {
  @override
  MealRecommendation recommend(
    MealLogEntry entry, {
    List<dynamic>? recentActivity,
    required DateTime now,
  }) {
    final reasonTags = <String>[];
    String message = '';

    final totalProtein = entry.nutrition.fold<double>(0, (sum, nut) => sum + nut.proteinG);
    final totalFat = entry.nutrition.fold<double>(0, (sum, nut) => sum + nut.fatG);
    final totalCalories = entry.totalCalories;

    final proteinRatio = totalCalories > 0 ? (totalProtein * 4) / totalCalories : 0;

    if (recentActivity != null && recentActivity.isNotEmpty) {
      final latestActivity = recentActivity.first;
      if (latestActivity is Map<String, dynamic>) {
        final endTime = latestActivity['end_time'] as DateTime?;
        if (endTime != null) {
          final timeSinceActivity = now.difference(endTime);
          if (timeSinceActivity.inHours <= 2 && proteinRatio > 0.2) {
            reasonTags.add('high_protein');
            reasonTags.add('post_workout_window');
            message = 'Great post-workout meal! High protein content supports muscle recovery.';
          }
        }
      }
    }

    if (reasonTags.isEmpty) {
      if (proteinRatio > 0.25) {
        reasonTags.add('high_protein');
        message = 'This meal is high in protein, which is great for satiety and muscle maintenance.';
      } else if (totalFat / totalCalories > 0.35) {
        reasonTags.add('high_fat');
        final hour = now.hour;
        if (hour >= 21) {
          reasonTags.add('late_eating');
          message = 'This meal is high in fat. Consider eating earlier next time for better digestion.';
        } else {
          message = 'This meal is high in healthy fats. Great for sustained energy.';
        }
      } else {
        switch (entry.mealType) {
          case MealType.breakfast:
            message = 'Good breakfast choice! A balanced start to your day.';
            break;
          case MealType.lunch:
            message = 'Balanced lunch to keep you energized for the afternoon.';
            break;
          case MealType.dinner:
            message = 'Well-rounded dinner. Try to finish eating 2-3 hours before bedtime.';
            break;
          case MealType.snack:
            message = 'Healthy snack choice. Keep portions moderate.';
            break;
        }
      }
    }

    return MealRecommendation(
      message: message,
      reasonTags: reasonTags,
    );
  }
}
