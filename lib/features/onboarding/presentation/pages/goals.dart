import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/onboarding/domain/entities/weight_goal.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/utils/onboarding_components.dart';

class GoalsPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const GoalsPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  GoalType _goal = GoalType.lose;
  WeeklyPace _pace = WeeklyPace.normal;
  int? _targetWeight;
  String _unit = 'kg';
  bool _showErrors = false;

  static const _units = ['kg', 'lb'];

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    _goal = GoalType.fromId(state.goalType) ?? GoalType.lose;
    _pace = WeeklyPace.fromId(state.weeklyPace) ?? WeeklyPace.normal;

    final savedUnit = state.targetWeight.isNotEmpty
        ? state.targetWeightUnit
        : state.weightUnit;
    _unit = _isPounds(savedUnit) ? 'lb' : 'kg';

    _targetWeight = state.targetWeight.isNotEmpty
        ? double.tryParse(state.targetWeight)?.round()
        : _currentWeightIn(_unit)?.round();
  }

  bool _isPounds(String unit) => unit.toLowerCase().startsWith('lb');

  double? get _currentKg {
    final state = context.read<OnboardingCubit>().state;
    return CalculateCalorieGoal.weightInKg(state.weight, state.weightUnit);
  }

  double? _currentWeightIn(String unit) {
    final kg = _currentKg;
    if (kg == null) return null;
    return _isPounds(unit) ? kg / CalculateCalorieGoal.kgPerLb : kg;
  }

  double? get _targetKg => _targetWeight == null
      ? null
      : CalculateCalorieGoal.weightInKg('$_targetWeight', _unit);

  /// Validation message for the current inputs, or null when valid.
  String? get _error {
    if (_goal == GoalType.maintain) return null;
    final target = _targetKg;
    if (target == null) return 'Enter your target weight.';
    final rangeError = ProfileRules.weightError(target);
    if (rangeError != null) return rangeError;
    final current = _currentKg;
    if (current == null) return null;
    if (_goal == GoalType.lose && target >= current) {
      return 'Pick a target below your current weight.';
    }
    if (_goal == GoalType.buildMuscle && target < current) {
      return 'Pick a target at or above your current weight.';
    }
    return null;
  }

  String _paceAmount(WeeklyPace pace) {
    if (_isPounds(_unit)) {
      final lb = pace.kgPerWeek * 2;
      return '${lb == lb.roundToDouble() ? lb.toInt() : lb} lb / week';
    }
    return '${pace.kgPerWeek} kg / week';
  }

  String _summary() {
    if (_goal == GoalType.maintain) {
      return "We'll set a daily calorie goal that keeps you at your current weight, based on your height, age and activity level.";
    }
    const calorieNote =
        "We'll calculate your daily calorie goal once you tell us your activity level.";
    final current = _currentKg;
    final target = _targetKg;
    if (current == null || target == null || _error != null) {
      return calorieNote;
    }
    final weeks = ((target - current).abs() / _pace.kgPerWeek).ceil();
    if (weeks == 0) return calorieNote;
    final timeframe = weeks < 8
        ? '$weeks ${weeks == 1 ? 'week' : 'weeks'}'
        : '${(weeks / CalculateCalorieGoal.weeksPerMonth).round()} months';
    return "At this pace you'll reach $_targetWeight $_unit in about $timeframe. $calorieNote";
  }

  void _changeUnit(String unit) {
    if (unit == _unit) return;
    setState(() {
      final w = _targetWeight;
      if (w != null) {
        _targetWeight = _isPounds(unit)
            ? (w / CalculateCalorieGoal.kgPerLb).round()
            : (w * CalculateCalorieGoal.kgPerLb).round();
      }
      _unit = unit;
    });
  }

  void _save() {
    final state = context.read<OnboardingCubit>().state;
    final isMaintain = _goal == GoalType.maintain;
    final current = _currentKg;
    final target = _targetKg;

    final months = (isMaintain || current == null || target == null)
        ? 0
        : CalculateCalorieGoal.monthsToTarget(
            currentKg: current,
            targetKg: target,
            pace: _pace,
          );

    context.read<OnboardingCubit>().updateGoals(
          goalType: _goal.id,
          weeklyPace: isMaintain ? '' : _pace.id,
          targetWeight: isMaintain ? state.weight : '${_targetWeight ?? ''}',
          targetWeightUnit: isMaintain ? state.weightUnit : _unit,
          goalDurationMonths: '$months',
        );
  }

  @override
  Widget build(BuildContext context) {
    final showTarget = _goal != GoalType.maintain;
    final error = _showErrors ? _error : null;
    final isPounds = _isPounds(_unit);

    return OnboardingLayout(
      step: 5,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        if (_error != null) {
          setState(() => _showErrors = true);
          return;
        }
        _save();
        widget.onNext?.call();
      },
      title: 'Your goal',
      subtitle: "We'll use this to personalise your nutrition plan.",
      nextEnabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Primary objective ──────────────────────────
          const _SectionLabel('What is your main goal?'),
          for (final goal in GoalType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.space16),
              child: OnboardingOptionTile(
                label: _goalLabel(goal),
                isSelected: _goal == goal,
                leading: Icon(
                  _goalIcon(goal),
                  size: AppDimens.iconXl,
                  color: context.colors.onSurface,
                ),
                onTap: () => setState(() {
                  _goal = goal;
                  _showErrors = false;
                }),
              ),
            ),

          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showTarget
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppDimens.space16),

                      // ── 2. Target weight ──────────────────
                      const _SectionLabel('Target weight'),
                      Center(
                        child: OnboardingNumberField<int>(
                          value: _targetWeight,
                          min: isPounds ? 66 : 30,
                          max: isPounds ? 550 : 250,
                          isError: error != null,
                          onValueChange: (v) => setState(() {
                            _targetWeight = v;
                            _showErrors = false;
                          }),
                        ),
                      ),
                      const SizedBox(height: AppDimens.space8),
                      Center(
                        child: UnitDropdown(
                          selectedUnit: _unit,
                          units: _units,
                          onUnitSelected: _changeUnit,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: AppDimens.space8),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall
                              ?.copyWith(color: context.colors.error),
                        ),
                      ],
                      const SizedBox(height: AppDimens.space32),

                      // ── 3. Weekly pace ────────────────────
                      const _SectionLabel('Weekly pace'),
                      for (final pace in WeeklyPace.values)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppDimens.space16),
                          child: OnboardingOptionTile(
                            label: '${_paceName(pace)}  ·  ${_paceAmount(pace)}',
                            isSelected: _pace == pace,
                            leading: _PaceDot(color: _paceColor(context, pace)),
                            onTap: () => setState(() => _pace = pace),
                          ),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),

          const SizedBox(height: AppDimens.space16),
          NoteRow(text: _summary()),
        ],
      ),
    );
  }

  static String _goalLabel(GoalType goal) => switch (goal) {
        GoalType.lose => 'Lose weight',
        GoalType.maintain => 'Maintain weight',
        GoalType.buildMuscle => 'Build muscle',
      };

  static IconData _goalIcon(GoalType goal) => switch (goal) {
        GoalType.lose => Icons.trending_down_rounded,
        GoalType.maintain => Icons.balance_rounded,
        GoalType.buildMuscle => Icons.fitness_center_rounded,
      };

  static String _paceName(WeeklyPace pace) => switch (pace) {
        WeeklyPace.relaxed => 'Relaxed',
        WeeklyPace.normal => 'Normal',
        WeeklyPace.aggressive => 'Aggressive',
      };

  static Color _paceColor(BuildContext context, WeeklyPace pace) =>
      switch (pace) {
        WeeklyPace.relaxed => context.vColors.success!,
        WeeklyPace.normal => context.vColors.warning!,
        WeeklyPace.aggressive => context.colors.error,
      };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space12),
      child: Text(text, style: context.text.titleSmall),
    );
  }
}

/// Traffic-light indicator for the pace options.
class _PaceDot extends StatelessWidget {
  final Color color;
  const _PaceDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.space12,
      height: AppDimens.space12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
