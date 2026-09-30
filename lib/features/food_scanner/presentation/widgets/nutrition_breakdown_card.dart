import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nutrition Breakdown', style: context.text.headlineSmall),
          const SizedBox(height: AppDimens.space16),
          _buildMacroRow(
            context,
            'Calories',
            FoodScanUtils.formatCalories(totalCalories),
            context.colors.primary,
          ),
          const SizedBox(height: AppDimens.space12),
          _buildMacroRow(
            context,
            'Protein',
            FoodScanUtils.formatMacro(totalProtein, 'g'),
            AppColors.scanProtein,
          ),
          const SizedBox(height: AppDimens.space12),
          _buildMacroRow(
            context,
            'Carbs',
            FoodScanUtils.formatMacro(totalCarbs, 'g'),
            AppColors.scanCarbs,
          ),
          const SizedBox(height: AppDimens.space12),
          _buildMacroRow(
            context,
            'Fat',
            FoodScanUtils.formatMacro(totalFat, 'g'),
            AppColors.scanFat,
          ),
          const SizedBox(height: AppDimens.space16),
          _buildMacroProgressBar(context, proteinRatio, carbRatio, fatRatio),
        ],
      ),
    );
  }

  Widget _buildMacroRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        _Dot(color: color, size: AppDimens.space12),
        const SizedBox(width: AppDimens.space8),
        Expanded(child: Text(label, style: context.text.bodyMedium)),
        Text(
          value,
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMacroProgressBar(
    BuildContext context,
    double proteinRatio,
    double carbRatio,
    double fatRatio,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Macro Distribution',
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppDimens.space8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: Container(
            height: AppDimens.progressHeight,
            color: context.vColors.track,
            child: Row(
              children: [
                Expanded(
                  flex: (proteinRatio * 100).toInt(),
                  child: const ColoredBox(color: AppColors.scanProtein),
                ),
                Expanded(
                  flex: (carbRatio * 100).toInt(),
                  child: const ColoredBox(color: AppColors.scanCarbs),
                ),
                Expanded(
                  flex: (fatRatio * 100).toInt(),
                  child: const ColoredBox(color: AppColors.scanFat),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: AppDimens.space12,
          runSpacing: AppDimens.space4,
          children: [
            _buildLegend(context, 'Protein', AppColors.scanProtein, proteinRatio),
            _buildLegend(context, 'Carbs', AppColors.scanCarbs, carbRatio),
            _buildLegend(context, 'Fat', AppColors.scanFat, fatRatio),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(
    BuildContext context,
    String label,
    Color color,
    double ratio,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: color, size: AppDimens.space8),
        const SizedBox(width: AppDimens.space4),
        Text(
          '$label ${(ratio * 100).toStringAsFixed(0)}%',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;

  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
