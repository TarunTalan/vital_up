import '../entities/nutrition_target.dart';
import '../../../onboarding/domain/entities/onboarding_data.dart';

class CalculateTargetFromOnboarding {
  NutritionTarget call(OnboardingData data, {String goal = 'maintain'}) {
    // 1. Parse Data
    final weightKg = _parseWeight(data.weight, data.weightUnit);
    final heightCm = _parseHeight(data.height, data.heightUnit);
    final age = _calculateAge(data.dob);
    final isMale = data.gender.toLowerCase() == 'male';

    // 2. BMR (Mifflin-St Jeor)
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    bmr += isMale ? 5 : -161;

    // 3. TDEE
    final activityMultiplier = _getActivityMultiplier(data.activity);
    double tdee = bmr * activityMultiplier;

    // Adjust for goal if provided (default maintain)
    if (goal == 'lose') {
      tdee -= 500;
    } else if (goal == 'gain') {
      tdee += 500;
    }
    
    int calories = tdee.round();
    if (calories < 1200) calories = 1200; // safety floor

    // 4. Macros
    // Default: 30% protein, 40% carbs, 30% fat
    double proteinPct = 0.30;
    double carbPct = 0.40;
    double fatPct = 0.30;

    // Adjust if diabetes
    if (data.healthConditions.toLowerCase().contains('diabetes')) {
      carbPct = 0.30;
      fatPct = 0.40;
    }

    final protein = ((calories * proteinPct) / 4).round();
    final carbs = ((calories * carbPct) / 4).round();
    final fat = ((calories * fatPct) / 9).round();

    return NutritionTarget(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  double _parseWeight(String weight, String unit) {
    final w = double.tryParse(weight) ?? 70.0;
    if (unit.toLowerCase() == 'lbs' || unit.toLowerCase() == 'lb') return w * 0.453592;
    return w;
  }

  double _parseHeight(String height, String unit) {
    final h = double.tryParse(height) ?? 170.0;
    if (unit.toLowerCase() == 'ft') {
      return h * 30.48; 
    }
    return h;
  }

  int _calculateAge(String dob) {
    // Expected formats: DD/MM/YYYY or YYYY-MM-DD
    try {
      if (dob.isEmpty) return 30;
      List<String> parts = dob.contains('/') ? dob.split('/') : dob.split('-');
      if (parts.length == 3) {
        final yearPart = parts.firstWhere((p) => p.length == 4, orElse: () => '');
        if (yearPart.isNotEmpty) {
          final year = int.parse(yearPart);
          int age = DateTime.now().year - year;
          if (age < 0 || age > 120) return 30;
          return age;
        }
      }
    } catch (e) {
      // fallback
    }
    return 30;
  }

  double _getActivityMultiplier(String activity) {
    final a = activity.toLowerCase();
    if (a.contains('sedentary')) return 1.2;
    if (a.contains('light')) return 1.375;
    if (a.contains('moderate')) return 1.55;
    if (a.contains('very')) return 1.725;
    if (a.contains('extra')) return 1.9;
    return 1.2; // default
  }
}
