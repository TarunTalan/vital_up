import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Nutrition & Food trends page matching the Figma design:
/// - Topbar with back & circular calendar action
/// - TODAY Calories Card with edit / log shortcut
/// - 7-DAY TREND column chart with highlighted active day
/// - Expandable Macros Card (Protein, Carbs, Fat + Fiber, Sugars, Saturated Fat)
/// - INSIGHTS gradient card
/// - Meals Logged list & quick logging buttons
class DietProgressPage extends StatefulWidget {
  const DietProgressPage({super.key});

  static String formatKcal(double v) => '${v.round()} kcal';

  @override
  State<DietProgressPage> createState() => _DietProgressPageState();
}

class _DietProgressPageState extends State<DietProgressPage> {
  DateTime? _selectedDay;
  bool _showMacroDetails = true;

  Future<void> _openDatePicker(BuildContext context) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  String _getInsightText(double calories, double goal) {
    if (calories <= 0) {
      return 'Log your meals today to track your daily calorie intake, macronutrient distribution, and health balance.';
    }
    if (goal > 0 && calories > goal * 1.15) {
      return 'You are slightly above your daily calorie target. A light evening walk can help steady your metabolic rhythm.';
    } else if (goal > 0 && calories < goal * 0.75) {
      return 'You are currently below your target calorie goal. Ensure you get enough balanced protein and fiber today.';
    }
    return 'This is about average for you. Consider setting boundaries before bed for better rest.';
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<DietPlanCubit>()..loadActiveMealPlan()),
        BlocProvider(
          create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
        ),
        BlocProvider(
          create: (_) => TrendCubit<MealLogEntry>(sl<TrendsService>().calories)..load(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final trendCubit = context.read<TrendCubit<MealLogEntry>>();
          final mealBloc = context.read<MealLogBloc>();

          return AppScaffold(
            header: AppPageHeader(
              title: 'Nutrition',
              action: AppHeaderAction(
                icon: const Icon(Icons.calendar_month_rounded),
                onTap: () => _openDatePicker(context),
              ),
            ),
            bottomBar: Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'History',
                    leadingIcon: const Icon(Icons.history_rounded, size: AppDimens.iconMd),
                    onTap: () => context.pushNamed('meal-log-history'),
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  flex: 2,
                  child: AppPrimaryButton(
                    label: 'Scan Food / Meal',
                    leadingIcon: const Icon(Icons.camera_alt_rounded, size: AppDimens.iconMd),
                    onTap: () async {
                      await context.pushNamed('food-scan');
                      if (context.mounted) {
                        mealBloc.add(const LoadTodaysMeals());
                        trendCubit.load();
                        try {
                          sl<HomeWidgetService>().refresh();
                        } catch (_) {}
                      }
                    },
                  ),
                ),
              ],
            ),
            onRefresh: () async {
              trendCubit.load();
              mealBloc.add(const LoadTodaysMeals());
              try {
                await sl<HomeWidgetService>().refresh();
              } catch (_) {}
            },
            body: BlocBuilder<TrendCubit<MealLogEntry>, TrendState<MealLogEntry>>(
              builder: (context, trendState) {
                return BlocBuilder<MealLogBloc, MealLogState>(
                  builder: (context, logState) {
                    final trendData = trendState.data;
                    if (trendData == null && trendState.error != null) {
                      return SizedBox(
                        height: 300,
                        child: LoadErrorView(onRetry: trendCubit.load),
                      );
                    }

                    if (trendData == null) {
                      return const SizedBox(
                        height: 300,
                        child: Center(child: VitalUpLoader()),
                      );
                    }

                    final v = context.vColors;
                    final now = DateTime.now();
                    final selectedDate = _selectedDay ?? now;
                    final isTodaySelected = isSameDay(selectedDate, now);

                    // 1. Calculate calories for selected day
                    DailyPoint? selectedPoint;
                    for (final p in trendData.series.points) {
                      if (isSameDay(p.day, selectedDate)) {
                        selectedPoint = p;
                        break;
                      }
                    }

                    double displayedCalories = selectedPoint?.value ?? 0.0;

                    // Compute nutrients from meal log state if today, or from trend logs for any selected day
                    double proteinG = 0;
                    double carbsG = 0;
                    double fatG = 0;
                    double fiberG = 0;
                    double sugarG = 0;
                    double satFatG = 0;
                    List<MealLogEntry> displayedLogs = [];

                    if (isTodaySelected && logState is MealLogLoaded && logState.entries.isNotEmpty) {
                      displayedCalories = logState.totalCalories > 0 ? logState.totalCalories : displayedCalories;
                      proteinG = logState.totalProteinG;
                      carbsG = logState.totalCarbsG;
                      fatG = logState.totalFatG;
                      displayedLogs = logState.entries;

                      for (final m in logState.entries) {
                        for (final n in m.nutrition) {
                          fiberG += n.fiberG;
                          sugarG += n.sugarG;
                          satFatG += n.saturatedFatG;
                        }
                      }
                    } else {
                      for (final m in trendData.logs) {
                        if (isSameDay(m.capturedAt, selectedDate)) {
                          displayedCalories += m.totalCalories;
                          displayedLogs.add(m);
                          for (final n in m.nutrition) {
                            proteinG += n.proteinG;
                            carbsG += n.carbsG;
                            fatG += n.fatG;
                            fiberG += n.fiberG;
                            sugarG += n.sugarG;
                            satFatG += n.saturatedFatG;
                          }
                        }
                      }
                      if (displayedCalories <= 0 && selectedPoint?.value != null) {
                        displayedCalories = selectedPoint!.value!;
                      }
                    }

                    // Total macronutrients
                    final totalMacros = (proteinG + carbsG + fatG);
                    final proteinPct = totalMacros > 0 ? ((proteinG / totalMacros) * 100).round() : 33;
                    final carbsPct = totalMacros > 0 ? ((carbsG / totalMacros) * 100).round() : 33;
                    final fatPct = totalMacros > 0 ? ((fatG / totalMacros) * 100).round() : 34;

                    final todayLabel = isTodaySelected
                        ? 'TODAY'
                        : DateFormat('EEEE, d MMM').format(selectedDate).toUpperCase();

                    final goalCalories = trendData.series.goal ?? 2000.0;
                    final insight = _getInsightText(displayedCalories, goalCalories);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. TODAY Calories Card (Figma Style)
                        AppCard(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.space20,
                            vertical: AppDimens.space16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todayLabel,
                                style: context.text.labelSmall?.copyWith(
                                  color: v.grayText,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: AppDimens.space8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        displayedCalories.round().toString(),
                                        style: context.text.displaySmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 36,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: AppDimens.space6),
                                      Text(
                                        'kcal',
                                        style: context.text.titleMedium?.copyWith(
                                          color: v.grayText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => context.pushNamed('food-scan'),
                                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                      child: Padding(
                                        padding: const EdgeInsets.all(AppDimens.space8),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: AppDimens.iconLg,
                                          color: v.grayText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.space16),

                        // 2. 7-DAY TREND Bar Chart (Figma Style)
                        _Figma7DayNutritionTrendCard(
                          series: trendData.series,
                          selectedDay: _selectedDay,
                          onSelectDay: (day) {
                            setState(() => _selectedDay = day);
                          },
                        ),

                        const SizedBox(height: AppDimens.space16),

                        // 3. Macros Breakdown Card with Expandable Details (Figma Style)
                        _FigmaMacrosCard(
                          proteinG: proteinG,
                          carbsG: carbsG,
                          fatG: fatG,
                          proteinPct: proteinPct,
                          carbsPct: carbsPct,
                          fatPct: fatPct,
                          fiberG: fiberG,
                          sugarG: sugarG,
                          satFatG: satFatG,
                          totalMacrosG: totalMacros,
                          isExpanded: _showMacroDetails,
                          onToggleExpand: () => setState(() => _showMacroDetails = !_showMacroDetails),
                        ),

                        const SizedBox(height: AppDimens.space16),

                        // 4. INSIGHTS Gradient Card (Figma Style)
                        _FigmaNutritionInsightsCard(insight: insight),

                        const SizedBox(height: AppDimens.sectionGap),

                        // 5. Meals Logged List
                        Text('Meals logged', style: context.text.headlineSmall),
                        const SizedBox(height: AppDimens.cardGap),

                        if (displayedLogs.isEmpty && trendData.logs.isEmpty)
                          const AppInfoNote(message: 'No meals logged in this period yet.')
                        else
                          for (final meal in (displayedLogs.isNotEmpty ? displayedLogs : trendData.logs)) ...[
                            _buildMealLogTile(context, meal),
                            const SizedBox(height: AppDimens.space8),
                          ],
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealLogTile(BuildContext context, MealLogEntry meal) {
    return TrendLogTile(
      icon: Icons.restaurant_rounded,
      color: AppColors.primary,
      title: meal.items.isEmpty
          ? _mealTypeLabel(meal.mealType)
          : meal.items.map((i) => i.name).join(', '),
      subtitle:
          '${_mealTypeLabel(meal.mealType)} · ${DateFormat('EEE d MMM, h:mm a').format(meal.capturedAt)}',
      trailing: DietProgressPage.formatKcal(meal.totalCalories),
    );
  }

  String _mealTypeLabel(MealType type) => switch (type) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };
}

/// 7-DAY TREND column bar chart matching the Figma specification
class _Figma7DayNutritionTrendCard extends StatelessWidget {
  final TrendSeries series;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  const _Figma7DayNutritionTrendCard({
    required this.series,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final points = series.points.length >= 7
        ? series.points.sublist(series.points.length - 7)
        : series.points;

    double maxCalories = 2200.0;
    for (final p in points) {
      if (p.value != null && p.value! > maxCalories) {
        maxCalories = p.value!;
      }
    }
    maxCalories = maxCalories.clamp(1500.0, 3500.0);

    const maxBarHeight = 120.0;
    const minBarHeight = 18.0;

    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-DAY TREND',
            style: context.text.labelSmall?.copyWith(
              color: v.grayText,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppDimens.space20),
          SizedBox(
            height: 155,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < points.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: _buildBarColumn(
                      context: context,
                      point: points[i],
                      maxCalories: maxCalories,
                      maxBarHeight: maxBarHeight,
                      minBarHeight: minBarHeight,
                      now: now,
                      isDark: isDark,
                      v: v,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarColumn({
    required BuildContext context,
    required DailyPoint point,
    required double maxCalories,
    required double maxBarHeight,
    required double minBarHeight,
    required DateTime now,
    required bool isDark,
    required dynamic v,
  }) {
    final isToday = isSameDay(point.day, now);
    final isSelected = selectedDay != null && isSameDay(point.day, selectedDay!);
    final dayName = DateFormat('E').format(point.day);

    final calories = point.value ?? 0.0;
    final fraction = (calories / maxCalories).clamp(0.0, 1.0);
    final barHeight = calories > 0
        ? (minBarHeight + (maxBarHeight - minBarHeight) * fraction)
        : (minBarHeight * 0.6);

    final barColor = isToday
        ? AppColors.success
        : isSelected
            ? AppColors.primary
            : (isDark ? const Color(0xFF334155) : const Color(0xFFC4CBD1));

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelectDay(point.day);
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: maxBarHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: barHeight,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              dayName,
              style: context.text.bodySmall?.copyWith(
                color: isToday ? context.colors.onSurface : v.grayText,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Macros breakdown card matching the Figma design with progress bars and expandable details
class _FigmaMacrosCard extends StatelessWidget {
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int proteinPct;
  final int carbsPct;
  final int fatPct;
  final double fiberG;
  final double sugarG;
  final double satFatG;
  final double totalMacrosG;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _FigmaMacrosCard({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.fiberG,
    required this.sugarG,
    required this.satFatG,
    required this.totalMacrosG,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Macros + Less/More Details Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Macros',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleExpand();
                },
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        isExpanded ? 'Less Details' : 'More Details',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: AppDimens.space2),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7),
                        size: AppDimens.iconSm,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.space16),

          // 1. Protein Row
          _buildMacroItem(
            context: context,
            label: 'Protein',
            amountG: proteinG.round(),
            percentage: proteinPct,
            barColor: const Color(0xFF00BFA5), // Teal/emerald
            trackColor: isDark ? const Color(0xFF1E3A3A) : const Color(0xFFE0F2F1),
          ),

          const SizedBox(height: AppDimens.space16),

          // 2. Carbs Row
          _buildMacroItem(
            context: context,
            label: 'Carbs',
            amountG: carbsG.round(),
            percentage: carbsPct,
            barColor: const Color(0xFFF59E0B), // Amber/orange
            trackColor: isDark ? const Color(0xFF3D2F17) : const Color(0xFFFEF3C7),
          ),

          const SizedBox(height: AppDimens.space16),

          // 3. Fat Row
          _buildMacroItem(
            context: context,
            label: 'Fat',
            amountG: fatG.round(),
            percentage: fatPct,
            barColor: const Color(0xFFA855F7), // Purple/lavender
            trackColor: isDark ? const Color(0xFF332042) : const Color(0xFFF3E8FF),
          ),

          // Expandable Sub-Nutrients
          if (isExpanded) ...[
            const SizedBox(height: AppDimens.space16),
            Divider(color: context.colors.outlineVariant, height: 1),
            const SizedBox(height: AppDimens.space12),

            _buildSubNutrientRow(context, 'Dietary Fiber', '${fiberG.round()} g'),
            const SizedBox(height: AppDimens.space8),
            _buildSubNutrientRow(context, 'Total Sugars', '${sugarG.round()} g'),
            const SizedBox(height: AppDimens.space8),
            _buildSubNutrientRow(context, 'Saturated Fat', '${satFatG.round()} g'),

            const SizedBox(height: AppDimens.space12),
            Divider(color: context.colors.outlineVariant, height: 1),
            const SizedBox(height: AppDimens.space12),

            Text(
              'Total: ${totalMacrosG.round()}g of macronutrients',
              style: context.text.bodySmall?.copyWith(
                color: v.grayText,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroItem({
    required BuildContext context,
    required String label,
    required int amountG,
    required int percentage,
    required Color barColor,
    required Color trackColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            RichText(
              text: TextSpan(
                style: context.text.bodyMedium?.copyWith(fontSize: 14),
                children: [
                  TextSpan(
                    text: '$amountG g ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: '($percentage%)',
                    style: TextStyle(
                      color: context.vColors.grayText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space6),
        Container(
          width: double.infinity,
          height: 7,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (percentage / 100.0).clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNutrientRow(BuildContext context, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.85),
            fontSize: 13.5,
          ),
        ),
        Text(
          value,
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

/// INSIGHTS gradient card matching the Figma specification
class _FigmaNutritionInsightsCard extends StatelessWidget {
  final String insight;

  const _FigmaNutritionInsightsCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0E3D48).withValues(alpha: 0.7),
                  const Color(0xFF11382A).withValues(alpha: 0.6),
                ]
              : [
                  const Color(0xFFE0F7FA).withValues(alpha: 0.85),
                  const Color(0xFFE8F5E9).withValues(alpha: 0.65),
                ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1E525E)
              : const Color(0xFFB2EBF2).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blueGrey).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'INSIGHTS',
                style: context.text.labelSmall?.copyWith(
                  color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0D9488),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space10),
          Text(
            insight,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.9),
              height: 1.45,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
