import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'dashboard_card_header.dart';

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
          return const AppCard(
            width: double.infinity,
            child: DashboardCardLoading(),
          );
        }
        if (state is MealLogLoaded) {
          return _LoadedCard(state: state, onViewAll: onViewAll, onScanMeal: onScanMeal);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

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
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: "Today's Nutrition",
            iconAsset: 'assets/icons/fork_knife.svg',
            trailing: TextButton(
              onPressed: onViewAll,
              child: const Text('View All →'),
            ),
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          Row(
            children: [
              _CalorieRing(
                calories: state.totalCalories,
                goal: state.dailyCalorieGoal?.toDouble(),
                progress: state.calorieProgress,
              ),
              const SizedBox(width: AppDimens.space20),
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
                      color: AppColors.protein,
                    ),
                    const SizedBox(height: AppDimens.space8),
                    _MacroBar(
                      label: 'Carbs',
                      value: state.totalCarbsG,
                      maxValue: (state.dailyCalorieGoal != null)
                          ? (state.dailyCalorieGoal! * 0.5 / 4)
                          : 250,
                      color: AppColors.carbs,
                    ),
                    const SizedBox(height: AppDimens.space8),
                    _MacroBar(
                      label: 'Fat',
                      value: state.totalFatG,
                      maxValue: (state.dailyCalorieGoal != null)
                          ? (state.dailyCalorieGoal! * 0.2 / 9)
                          : 65,
                      color: AppColors.fat,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: MealType.values.map((mealType) {
              final logged = state.loggedMealTypes.contains(mealType);
              return Expanded(
                child: _MealSlot(
                  mealType: mealType,
                  logged: logged,
                  onTap: logged ? null : onScanMeal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

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
    return SizedBox.square(
      dimension: context.w(AppDimens.calorieRing),
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress ?? 0,
          trackColor: context.vColors.track!,
          progressColor: context.colors.primary,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  calories.toInt().toString(),
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.onSurface,
                    height: 1,
                  ),
                ),
                Text(
                  goal != null ? '/ ${goal!.toInt()}' : 'kcal',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.vColors.grayText),
                ),
              ],
            ),
          ),
        ),
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
    const strokeWidth = AppDimens.progressHeight;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
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
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

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
    final progress = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall
                    ?.copyWith(color: context.vColors.grayText),
              ),
            ),
            Text(
              '${value.toInt()}g',
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space4),
        AppProgressBar(
          value: progress,
          color: color,
          trackColor: color.withValues(alpha: 0.18),
          height: AppDimens.space6,
        ),
      ],
    );
  }
}

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
    final primary = context.colors.primary;
    final v = context.vColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            width: AppDimens.iconBadge,
            height: AppDimens.iconBadge,
            decoration: BoxDecoration(
              color: logged ? v.primaryTint : v.glassFill,
              shape: BoxShape.circle,
              border: Border.all(
                color: logged ? primary : v.glassBorder!,
                width: AppDimens.borderThin,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_emoji, style: context.text.titleSmall),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _label,
              maxLines: 1,
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: logged ? primary : v.grayText,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space2),
          Icon(
            logged ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
            size: AppDimens.iconXs,
            color: logged ? primary : v.grayText,
          ),
        ],
      ),
    );
  }
}
