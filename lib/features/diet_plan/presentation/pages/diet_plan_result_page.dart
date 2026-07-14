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
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

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
      _cubit.loadActiveMealPlan();
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

  DateTime? _lastRegenerateTime;

  void _regenerate() {
    final now = DateTime.now();
    if (_lastRegenerateTime != null && now.difference(_lastRegenerateTime!).inSeconds < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait a moment before trying again.')),
      );
      return;
    }
    _lastRegenerateTime = now;

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
      child: AuthBackground(
        child: BlocBuilder<DietPlanCubit, DietPlanState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Your Diet Plan'),
                backgroundColor: Colors.transparent,
              ),
              bottomNavigationBar: state is DietPlanLoaded && _mode != 'cached'
                  ? _buildBottomActions(context, state.mealPlan)
                  : null,
              body: Builder(
                builder: (context) {
                  if (state is DietPlanLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VitalUpLoader(),
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
                  return const Center(child: Text('No active plan found.'));
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, MealPlan plan) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.hPadding, 8, AppTheme.hPadding, 16),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: AppTheme.buttonHeight,
                child: OutlinedButton(
                  onPressed: _regenerate,
                  child: const Text('Regenerate'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: AppTheme.buttonHeight,
                child: FilledButton(
                  onPressed: () async {
                    await _cubit.saveActivePlan(plan);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Active plan saved successfully!')),
                      );
                      context.goNamed('dashboard');
                    }
                  },
                  child: const Text('Set as Active Plan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(BuildContext context, MealPlan plan) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.hPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMacroRing(context, plan),
          const SizedBox(height: 32),
          Text('Meals', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: plan.meals.map((m) => _MealCard(meal: m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRing(BuildContext context, MealPlan plan) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cardColor = theme.cardTheme.color ?? Colors.white;
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.72),
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
    final cardColor = theme.cardTheme.color ?? Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.72),
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
