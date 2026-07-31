import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';

/// Today's nutrition summary card shown on the Dashboard home tab.
/// Requires [MealLogBloc] to be provided above this widget in the tree.
class NutritionSummaryCard extends StatelessWidget {
  /// Called when the user taps "View All" — navigate to MealLogHistoryPage.
  final VoidCallback? onViewAll;

  /// Called when a meal-type slot with no entry is tapped — open the scanner.
  final VoidCallback? onScanMeal;

  const NutritionSummaryCard({
    super.key,
    this.onViewAll,
    this.onScanMeal,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MealLogBloc, MealLogState>(
      builder: (context, state) {
        if (state is MealLogLoading) {
          return const _LoadingCard();
        }
        if (state is MealLogLoaded) {
          return _LoadedCard(state: state, onViewAll: onViewAll, onScanMeal: onScanMeal);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _CardShell(
      child: SizedBox(
        height: 140,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loaded state card
// ─────────────────────────────────────────────────────────────────
class _LoadedCard extends StatelessWidget {
  final MealLogLoaded state;
  final VoidCallback? onViewAll;
  final VoidCallback? onScanMeal;

  const _LoadedCard({
    required this.state,
    this.onViewAll,
    this.onScanMeal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              Text(
                "Today's Nutrition",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'View All →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Calorie ring + macros ────────────────────────────────
          Row(
            children: [
              _CalorieRing(
                calories: state.totalCalories,
                goal: state.dailyCalorieGoal?.toDouble(),
                progress: state.calorieProgress,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroBar(
                      label: 'Protein',
                      value: state.totalProteinG,
                      maxValue: (state.dailyCalorieGoal != null)
                          ? (state.dailyCalorieGoal! * 0.3 / 4)
                          : 120,
                      color: const Color(0xFF5B8DEF),
                    ),
                    const SizedBox(height: 8),
                    _MacroBar(
                      label: 'Carbs',
                      value: state.totalCarbsG,
                      maxValue: (state.dailyCalorieGoal != null)
                          ? (state.dailyCalorieGoal! * 0.5 / 4)
                          : 250,
                      color: const Color(0xFF6DC16D),
                    ),
                    const SizedBox(height: 8),
                    _MacroBar(
                      label: 'Fat',
                      value: state.totalFatG,
                      maxValue: (state.dailyCalorieGoal != null)
                          ? (state.dailyCalorieGoal! * 0.2 / 9)
                          : 65,
                      color: const Color(0xFFEF8C5B),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Meal slot row ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: MealType.values.map((mealType) {
              final logged = state.loggedMealTypes.contains(mealType);
              return _MealSlot(
                mealType: mealType,
                logged: logged,
                onTap: logged ? null : onScanMeal,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Calorie ring (arc progress)
// ─────────────────────────────────────────────────────────────────
class _CalorieRing extends StatelessWidget {
  final double calories;
  final double? goal;
  final double? progress;

  const _CalorieRing({
    required this.calories,
    required this.goal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final p = progress ?? 0;

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(80, 80),
            painter: _RingPainter(
              progress: p,
              trackColor: colors.surfaceContainerHighest,
              progressColor: colors.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                calories.toInt().toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  height: 1,
                ),
              ),
              Text(
                goal != null ? '/ ${goal!.toInt()}' : 'kcal',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    const strokeWidth = 8.0;
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────────
// Macro bar
// ─────────────────────────────────────────────────────────────────
class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              '${value.toInt()}g',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Meal slot chip
// ─────────────────────────────────────────────────────────────────
class _MealSlot extends StatelessWidget {
  final MealType mealType;
  final bool logged;
  final VoidCallback? onTap;

  const _MealSlot({
    required this.mealType,
    required this.logged,
    this.onTap,
  });

  String get _emoji {
    switch (mealType) {
      case MealType.breakfast: return '🌅';
      case MealType.lunch:     return '☀️';
      case MealType.dinner:    return '🌙';
      case MealType.snack:     return '🍎';
    }
  }

  String get _label {
    switch (mealType) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
      case MealType.snack:     return 'Snack';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: logged
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: logged ? colors.primary : colors.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: logged
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Icon(
            logged ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
            size: 12,
            color: logged
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Glassmorphic card shell
// ─────────────────────────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }
}
