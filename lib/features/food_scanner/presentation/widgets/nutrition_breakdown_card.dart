import 'package:flutter/material.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/food_scan_utils.dart';

class NutritionBreakdownCard extends StatelessWidget {
  final List<NutritionInfo> nutrition;

  const NutritionBreakdownCard({
    super.key,
    required this.nutrition,
  });

  @override
  Widget build(BuildContext context) {
    final totalCalories = FoodScanUtils.calculateTotalCalories(nutrition);
    final totalProtein = FoodScanUtils.calculateTotalProtein(nutrition);
    final totalCarbs = FoodScanUtils.calculateTotalCarbs(nutrition);
    final totalFat = FoodScanUtils.calculateTotalFat(nutrition);

    final proteinRatio = FoodScanUtils.calculateProteinRatio(nutrition);
    final carbRatio = FoodScanUtils.calculateCarbRatio(nutrition);
    final fatRatio = FoodScanUtils.calculateFatRatio(nutrition);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutrition Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMacroRow(
              'Calories',
              FoodScanUtils.formatCalories(totalCalories),
              Colors.orange,
              1.0,
            ),
            const SizedBox(height: 12),
            _buildMacroRow(
              'Protein',
              FoodScanUtils.formatMacro(totalProtein, 'g'),
              Colors.red,
              proteinRatio,
            ),
            const SizedBox(height: 12),
            _buildMacroRow(
              'Carbs',
              FoodScanUtils.formatMacro(totalCarbs, 'g'),
              Colors.blue,
              carbRatio,
            ),
            const SizedBox(height: 12),
            _buildMacroRow(
              'Fat',
              FoodScanUtils.formatMacro(totalFat, 'g'),
              Colors.yellow,
              fatRatio,
            ),
            const SizedBox(height: 16),
            _buildMacroProgressBar(proteinRatio, carbRatio, fatRatio),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color, double ratio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroProgressBar(double proteinRatio, double carbRatio, double fatRatio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Macro Distribution',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[200],
          ),
          child: Row(
            children: [
              Expanded(
                flex: (proteinRatio * 100).toInt(),
                child: Container(
                  color: Colors.red,
                ),
              ),
              Expanded(
                flex: (carbRatio * 100).toInt(),
                child: Container(
                  color: Colors.blue,
                ),
              ),
              Expanded(
                flex: (fatRatio * 100).toInt(),
                child: Container(
                  color: Colors.yellow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegend('Protein', Colors.red, proteinRatio),
            _buildLegend('Carbs', Colors.blue, carbRatio),
            _buildLegend('Fat', Colors.yellow, fatRatio),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color, double ratio) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${(ratio * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
