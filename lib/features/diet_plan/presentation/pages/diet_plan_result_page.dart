import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/calculate_target_from_goal.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/calculate_target_from_onboarding.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_chat_page.dart';

class DietPlanResultPage extends StatefulWidget {
  final Map<String, dynamic> params;

  const DietPlanResultPage({super.key, required this.params});

  @override
  State<DietPlanResultPage> createState() => _DietPlanResultPageState();
}

class _DietPlanResultPageState extends State<DietPlanResultPage> {
  late DietPlanCubit _cubit;
  NutritionTarget? _target;
  late Map<String, dynamic> _preferences;
  String _mode = 'cached';

  /// Last tweak request, so "Try Again" after a failure retries the tweak.
  String? _instructions;
  MealPlan? _basePlan;

  @override
  void initState() {
    super.initState();
    _cubit = sl<DietPlanCubit>();
    _mode = widget.params['mode'] as String? ?? 'cached';
    _preferences = widget.params['preferences'] as Map<String, dynamic>? ?? {};
    
    if (_mode == 'cached') {
      _cubit.loadActiveMealPlan();
    } else {
      _calculateAndGenerate();
    }
  }

  Future<void> _calculateAndGenerate() async {
    try {
      if (_mode == 'tweak') {
        // Opened from Vita: tweak the active plan with its saved preferences.
        final getActive = sl<GetActiveMealPlan>();
        final base = await getActive();
        if (base == null) {
          _cubit.showError(
            'Create a diet plan first, then ask Vita to tweak it.',
          );
          return;
        }
        _preferences = await getActive.preferences();
        _target = NutritionTarget(
          calories: base.totalCalories,
          protein: base.totalProtein,
          carbs: base.totalCarbs,
          fat: base.totalFat,
        );
        _tweak(widget.params['instructions'] as String, base);
        return;
      }
      if (_mode == 'manual') {
        _target = widget.params['target'] as NutritionTarget;
      } else {
        final store = sl<OnboardingDataStore>();
        final weight = await store.getWeight();
        final weightUnit = await store.getWeightUnit();
        final height = await store.getHeight();
        final heightUnit = await store.getHeightUnit();
        final dob = await store.getDob();
        final gender = await store.getGender();
        final activity = await store.getActivity();
        final healthConditions = await store.getHealthConditions();
        
        final onboardingData = OnboardingData(
          weight: weight,
          weightUnit: weightUnit,
          height: height,
          heightUnit: heightUnit,
          dob: dob,
          gender: gender,
          activity: activity,
          healthConditions: healthConditions,
        );
        
        final calcOnboarding = CalculateTargetFromOnboarding();
        
        if (_mode == 'smart') {
          _target = calcOnboarding(onboardingData);
        } else if (_mode == 'goal') {
          final targetWeight = widget.params['targetWeight'] as double;
          final timeframe = widget.params['timeframe'] as int;
          
          final baseTarget = calcOnboarding(onboardingData);
          final currentWeight = double.tryParse(onboardingData.weight) ?? 70.0;
          
          final calcGoal = CalculateTargetFromGoal();
          _target = calcGoal(
            currentTdee: baseTarget.calories.toDouble(),
            currentWeightKg: currentWeight,
            targetWeightKg: targetWeight,
            timeframeWeeks: timeframe,
            isMuscleGainGoal: targetWeight > currentWeight,
          );
        }
      }
      
      if (_target != null) {
        _cubit.generatePlan(target: _target!, preferences: _preferences);
      }
    } catch (e) {
      _cubit.showError('Failed to calculate target: $e');
    }
  }

  DateTime? _lastRegenerateTime;

  void _regenerate() {
    final now = DateTime.now();
    if (_lastRegenerateTime != null && now.difference(_lastRegenerateTime!).inSeconds < 5) {
      showSmoothSnackBar(
        context,
        message: 'Please wait a moment before trying again.',
        iconColor: AppColors.warning,
      );
      return;
    }
    _lastRegenerateTime = now;

    _instructions = null;
    _basePlan = null;
    if (_target != null) {
      _cubit.generatePlan(target: _target!, preferences: _preferences);
    }
  }

  void _tweak(String instructions, MealPlan base) {
    _instructions = instructions;
    _basePlan = base;
    _cubit.generatePlan(
      target: _target!,
      preferences: _preferences,
      instructions: instructions,
      basePlan: base,
    );
  }

  /// Retries whatever failed: the last tweak, or a fresh plan.
  void _retry() {
    final instructions = _instructions;
    final base = _basePlan;
    if (instructions != null && base != null) {
      _tweak(instructions, base);
    } else {
      _regenerate();
    }
  }

  Future<void> _tweakWithVita(MealPlan plan) async {
    final instructions = await context.pushNamed<String>(
      'vita-chat',
      extra: VitaChatArgs(
        initialPrompt: "I'd like to make some changes to this diet plan.",
        draftPlan: plan,
      ),
    );
    if (!mounted || instructions == null || _target == null) return;
    _tweak(instructions, plan);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<DietPlanCubit, DietPlanState>(
        builder: (context, state) {
          return AppScaffold(
            header: const AppPageHeader(title: 'Your Diet Plan'),
            scrollable: false,
            padBody: false,
            bottomBar: state is DietPlanLoaded && _mode != 'cached'
                ? _buildBottomActions(context, state.mealPlan)
                : null,
            body: Builder(
              builder: (context) {
                if (state is DietPlanLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const VitalUpLoader(),
                        const SizedBox(height: AppDimens.space16),
                        Text(
                          'Generating your personalized plan...',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.vColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (state is DietPlanLoaded) {
                  return _buildPlanContent(context, state.mealPlan);
                } else if (state is DietPlanError) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(context.gutter),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconBadge(
                            icon: const Icon(Icons.error_outline_rounded),
                            color: context.colors.error,
                            size: AppDimens.iconXxl,
                          ),
                          const SizedBox(height: AppDimens.space16),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium,
                          ),
                          const SizedBox(height: AppDimens.sectionGap),
                          if (_target != null)
                            AppPrimaryButton(
                              label: 'Try Again',
                              onTap: _retry,
                              expand: false,
                            ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: Text(
                    'No active plan found.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, MealPlan plan) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Regenerate',
                onTap: _regenerate,
              ),
            ),
            const SizedBox(width: AppDimens.cardGap),
            Expanded(
              child: AppSecondaryButton(
                label: 'Tweak with Vita',
                onTap: () => _tweakWithVita(plan),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space12),
        AppPrimaryButton(
          label: 'Set as Active Plan',
          onTap: () async {
            await _cubit.saveActivePlan(plan, preferences: _preferences);
            if (context.mounted) {
              showSuccessSnackBar(context, 'Active plan saved successfully!');
              context.goNamed('dashboard');
            }
          },
        ),
      ],
    );
  }

  Widget _buildPlanContent(BuildContext context, MealPlan plan) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.sectionGap,
        context.gutter,
        AppDimens.sectionGap,
      ),
      children: [
        _buildMacroRing(context, plan),
        const SizedBox(height: AppDimens.sectionGap),
        Text('Meals', style: context.text.headlineSmall),
        const SizedBox(height: AppDimens.cardGap),
        for (final meal in plan.meals) ...[
          _MealCard(meal: meal),
          const SizedBox(height: AppDimens.cardGap),
        ],
      ],
    );
  }

  Widget _buildMacroRing(BuildContext context, MealPlan plan) {
    final hole = context.w(AppDimens.donutHole);
    final thickness = context.w(AppDimens.donutThickness);
    // Values live in the legend below — the ring is too thin to hold
    // "120g Protein" without clipping, especially on small slices.
    PieChartSectionData section(Color color, int value) {
      return PieChartSectionData(
        color: color,
        value: value.toDouble(),
        radius: thickness,
        showTitle: false,
      );
    }

    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCaption('Daily target'),
          const SizedBox(height: AppDimens.space12),
          SizedBox(
            height: (hole + thickness) * 2 + AppDimens.space8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: AppDimens.space4,
                    centerSpaceRadius: hole,
                    sections: [
                      section(AppColors.protein, plan.totalProtein),
                      section(AppColors.carbs, plan.totalCarbs),
                      section(AppColors.fat, plan.totalFat),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${plan.totalCalories}',
                        style: AppTextStyles.metric.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                      Text(
                        'kcal',
                        style: context.text.bodySmall?.copyWith(
                          color: context.vColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppDimens.space16,
              runSpacing: AppDimens.space8,
              children: [
                _MacroLegend(
                  color: AppColors.protein,
                  label: 'Protein',
                  grams: plan.totalProtein,
                ),
                _MacroLegend(
                  color: AppColors.carbs,
                  label: 'Carbs',
                  grams: plan.totalCarbs,
                ),
                _MacroLegend(
                  color: AppColors.fat,
                  label: 'Fat',
                  grams: plan.totalFat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour dot + "Protein 120g" key for the daily-target ring.
class _MacroLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int grams;

  const _MacroLegend({
    required this.color,
    required this.label,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppDimens.space8,
          height: AppDimens.space8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimens.space6),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
        const SizedBox(width: AppDimens.space4),
        Text(
          '${grams}g',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final grey = v.grayText;

    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(meal.name, style: context.text.titleSmall),
              ),
              const SizedBox(width: AppDimens.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: AppDimens.space4,
                ),
                decoration: BoxDecoration(
                  color: v.primaryTint,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  '${meal.calories} kcal',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            'P: ${meal.protein}g  C: ${meal.carbs}g  F: ${meal.fat}g',
            style: context.text.bodySmall?.copyWith(color: grey),
          ),
          const SizedBox(height: AppDimens.space12),
          ...meal.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(
                left: AppDimens.space16,
                bottom: AppDimens.space4,
              ),
              child: Text(
                item,
                style: context.text.bodyMedium?.copyWith(color: grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
