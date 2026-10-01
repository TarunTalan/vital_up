import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_colors.dart';

/// Score buckets points are earned in (`score_categories` on the server).
/// Bonus points (streaks, badges) count toward the total only.
enum ScoreCategory {
  nutrition('Nutrition', AppColors.scoreNutrition, Icons.restaurant_rounded),
  lifestyle(
    'Lifestyle',
    AppColors.scoreLifestyle,
    Icons.self_improvement_rounded,
  ),
  fitness('Fitness', AppColors.scoreFitness, Icons.directions_run_rounded),
  bonus('Bonus', AppColors.scoreBonus, Icons.auto_awesome_rounded);

  final String label;
  final Color color;
  final IconData icon;
  const ScoreCategory(this.label, this.color, this.icon);

  /// The three categories users earn in directly.
  static const scored = [nutrition, lifestyle, fitness];

  static ScoreCategory? fromCode(String? code) {
    for (final c in values) {
      if (c.name == code) return c;
    }
    return null;
  }
}
