import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/calculate_target_from_goal.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/calculate_target_from_onboarding.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';

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

  @override
  void initState() {
    super.initState();
    _cubit = sl<DietPlanCubit>();
    _mode = widget.params['mode'] as String? ?? 'cached';
    _preferences = widget.params['preferences'] as Map<String, dynamic>? ?? {};
    
    if (_mode == 'cached') {
      _cubit.loadTodayMealPlan();
    } else {
      _calculateAndGenerate();
    }
  }

  Future<void> _calculateAndGenerate() async {
    try {
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
      _cubit.emit(DietPlanError('Failed to calculate target: $e'));
    }
  }

  void _regenerate() {
    if (_target != null) {
      _cubit.generatePlan(target: _target!, preferences: _preferences);
    }
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
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Your Diet Plan'),
          backgroundColor: Colors.transparent,
          actions: [
            if (_target != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _regenerate,
              ),
          ],
        ),
        body: BlocBuilder<DietPlanCubit, DietPlanState>(
          builder: (context, state) {
            if (state is DietPlanLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating your personalized plan...'),
                  ],
                ),
              );
            } else if (state is DietPlanLoaded) {
              return _buildPlanContent(context, state.mealPlan);
            } else if (state is DietPlanError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (_target != null)
                        FilledButton(
                          onPressed: _regenerate,
                          child: const Text('Try Again'),
                        ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: Text('No plan found for today.'));
          },
        ),
      ),
    );
  }

  Widget _buildPlanContent(BuildContext context, MealPlan plan) {
    final theme = Theme.of(context);
    
    return ListView(
      padding: const EdgeInsets.all(AppTheme.hPadding),
      children: [
        _buildMacroRing(context, plan),
        const SizedBox(height: 32),
        Text('Meals', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        ...plan.meals.map((m) => _MealCard(meal: m)),
      ],
    );
  }

  Widget _buildMacroRing(BuildContext context, MealPlan plan) {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: [
                PieChartSectionData(
                  color: Colors.redAccent,
                  value: plan.totalProtein.toDouble(),
                  title: '${plan.totalProtein}g\nPro',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  color: Colors.blueAccent,
                  value: plan.totalCarbs.toDouble(),
                  title: '${plan.totalCarbs}g\nCarb',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  color: Colors.orangeAccent,
                  value: plan.totalFat.toDouble(),
                  title: '${plan.totalFat}g\nFat',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${plan.totalCalories}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'kcal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(meal.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text('${meal.calories} kcal', style: theme.textTheme.titleSmall?.copyWith(color: colors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('P: ${meal.protein}g  C: ${meal.carbs}g  F: ${meal.fat}g', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...meal.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
