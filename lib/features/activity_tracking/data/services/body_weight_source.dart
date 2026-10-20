import 'package:flutter/foundation.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// The user's current weight in kg for workout calories: the latest
/// weight entry, else the weight on the profile (onboarding, Health
/// details). Null when neither is known; callers use an average weight.
class BodyWeightSource {
  final WeightService weights;
  final ProfileRepository profiles;

  BodyWeightSource({required this.weights, required this.profiles});

  Future<double?> call() async {
    try {
      final latest = await weights.latest();
      final kg = latest?.weightKg;
      if (kg != null && kg.isFinite && kg > 0) return kg;
    } catch (e) {
      debugPrint('Reading the latest weight failed: $e');
    }
    try {
      final profile = await profiles.getProfile();
      return profile.fold((_) => null, (p) {
        final kg = CalculateCalorieGoal.weightInKg(p.weight, p.weightUnit);
        return kg != null && kg.isFinite && kg > 0 ? kg : null;
      });
    } catch (e) {
      debugPrint('Reading the profile weight failed: $e');
      return null;
    }
  }
}
