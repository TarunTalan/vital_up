import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

/// "1,840 kcal".
String formatMealKcal(double kcal) =>
    '${NumberFormat.decimalPattern().format(kcal.round())} kcal';

/// One meal as a [LogHistoryCard]: what was eaten, the meal and time, its
/// calories, and the macros summed over every item.
class MealLogCard extends StatelessWidget {
  final MealLogEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MealLogCard({super.key, required this.entry, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final label = mealTypeLabel(entry.mealType);
    final names = entry.items.map((i) => i.name).join(', ');
    return LogHistoryCard(
      icon: Icon(mealTypeIcon(entry.mealType)),
      color: TrackerMetric.nutrition.color,
      title: names.isEmpty ? label : names,
      subtitle: '$label · ${DateFormat.jm().format(entry.capturedAt)}',
      value: formatMealKcal(entry.totalCalories),
      onTap: onTap,
      onDelete: onDelete,
      deleteNoun: 'meal',
      figures: entry.nutrition.isEmpty
          ? const []
          : [
              LogFigure('${_sum(entry, (n) => n.proteinG)} g', 'Protein'),
              LogFigure('${_sum(entry, (n) => n.carbsG)} g', 'Carbs'),
              LogFigure('${_sum(entry, (n) => n.fatG)} g', 'Fat'),
            ],
    );
  }
}

/// A macro over every item of the meal (the calories shown are the total).
int _sum(MealLogEntry entry, double Function(NutritionInfo n) of) =>
    entry.nutrition.fold<double>(0, (sum, n) => sum + of(n)).round();
