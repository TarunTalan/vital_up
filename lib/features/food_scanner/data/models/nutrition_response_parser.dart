import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

/// Parses the scan-food edge function's nutrition payload (the `get_nutrition`
/// response and the inline `nutrition` block of each recognized item).
///
/// The payload only carries numbers, never the item it describes, so the
/// [item] this lookup was for is attached directly.
NutritionInfo parseNutritionResponse(Map<String, dynamic> data, FoodItem item) {
  double num_(String key) => (data[key] as num?)?.toDouble() ?? 0.0;

  final additionalNutrients = (data['additional_nutrients'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map((e) => AdditionalNutrient(
                id: e['id']?.toString(),
                name: e['name'] as String? ?? '',
                unit: e['unit'] as String? ?? '',
                value: (e['value'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList() ??
      const <AdditionalNutrient>[];

  double calories = num_('calories');

  // Safeguard: Check if the returned calories value is actually in kJ (kilojoules)
  // If we find an 'Energy' nutrient with unit 'kJ' and matching value, we convert it to kcal.
  final hasKjEnergy = additionalNutrients.any((n) =>
      (n.name.toLowerCase() == 'energy' || n.id == '1062') &&
      n.unit.toLowerCase() == 'kj' &&
      (n.value - calories).abs() < 0.1);
  if (hasKjEnergy && calories > 0) {
    calories = calories / 4.184;
  }

  return NutritionInfo(
    calories: calories,
    proteinG: num_('protein_g'),
    carbsG: num_('carbs_g'),
    fatG: num_('fat_g'),
    fiberG: num_('fiber_g'),
    sugarG: num_('sugar_g'),
    sodiumMg: num_('sodium_mg'),
    calciumMg: num_('calcium_mg'),
    ironMg: num_('iron_mg'),
    vitaminAIu: num_('vitamin_a_iu'),
    vitaminCMg: num_('vitamin_c_mg'),
    vitaminDIu: num_('vitamin_d_iu'),
    vitaminEMg: num_('vitamin_e_mg'),
    vitaminKMg: num_('vitamin_k_mg'),
    thiaminMg: num_('thiamin_mg'),
    riboflavinMg: num_('riboflavin_mg'),
    niacinMg: num_('niacin_mg'),
    vitaminB6Mg: num_('vitamin_b6_mg'),
    vitaminB12Mcg: num_('vitamin_b12_mcg'),
    folateMcg: num_('folate_mcg'),
    potassiumMg: num_('potassium_mg'),
    phosphorusMg: num_('phosphorus_mg'),
    magnesiumMg: num_('magnesium_mg'),
    zincMg: num_('zinc_mg'),
    copperMg: num_('copper_mg'),
    manganeseMg: num_('manganese_mg'),
    seleniumMcg: num_('selenium_mcg'),
    cholesterolMg: num_('cholesterol_mg'),
    saturatedFatG: num_('saturated_fat_g'),
    transFatG: num_('trans_fat_g'),
    monounsaturatedFatG: num_('monounsaturated_fat_g'),
    polyunsaturatedFatG: num_('polyunsaturated_fat_g'),
    additionalNutrients: additionalNutrients,
    per: item,
  );
}
