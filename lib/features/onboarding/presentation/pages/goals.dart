import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import 'package:vital_up/features/onboarding/domain/entities/weight_goal.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Step 5: the main goal, and for losing or gaining, a target weight (on
/// the weight scale, in the unit picked on the weight step) and a weekly
/// pace with the time it would take.
class GoalStep extends StatefulWidget {
  final int revealFrom;

  const GoalStep({super.key, this.revealFrom = 3});

  @override
  State<GoalStep> createState() => _GoalStepState();
}

class _GoalStepState extends State<GoalStep> with OnboardingStepState {
  /// How far the suggested target sits from today's weight.
  static const _suggestLoseKg = 5.0;
  static const _suggestGainKg = 3.0;

  /// Typical weight to start the scale from when none was given.
  static const _fallbackKg = 70.0;

  late GoalType _goal;
  late WeeklyPace _pace;

  /// The target in [_unit], to 0.5.
  late double _target;
  late final String _code;
  bool _showErrors = false;

  WeightUnit get _unit => WeightUnit.fromCode(_code);

  double? get _currentKg {
    final state = context.read<OnboardingCubit>().state;
    return CalculateCalorieGoal.weightInKg(state.weight, state.weightUnit);
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    _goal = GoalType.fromId(state.goalType) ?? GoalType.lose;
    _pace = WeeklyPace.fromId(state.weeklyPace) ?? WeeklyPace.normal;
    // The weight step's unit, so both read alike.
    _code = WeightUnit.fromCode(state.weightUnit) == WeightUnit.lbs
        ? 'lb'
        : 'kg';
    final savedKg = CalculateCalorieGoal.weightInKg(
      state.targetWeight,
      state.targetWeightUnit,
    );
    _target = _inUnit(
      savedKg != null && _errorFor(_goal, savedKg) == null
          ? savedKg
          : _suggestedKg(_goal),
    );
  }

  static double _half(double v) => (v * 2).round() / 2;

  double _inUnit(double kg) => _half(
    _unit
        .fromKg(kg)
        .clamp(_unit.minValue.toDouble(), _unit.maxValue.toDouble()),
  );

  double get _targetKg => _unit.toKg(_target);

  /// A target that fits [goal]: a little under today's weight to lose, a
  /// little over to build muscle.
  double _suggestedKg(GoalType goal) {
    final current = _currentKg ?? _fallbackKg;
    return switch (goal) {
      GoalType.lose => current - _suggestLoseKg,
      GoalType.buildMuscle => current + _suggestGainKg,
      GoalType.maintain => current,
    };
  }

  /// Why [targetKg] doesn't fit [goal], or null when it does.
  String? _errorFor(GoalType goal, double targetKg) {
    if (goal == GoalType.maintain) return null;
    final range = ProfileRules.weightError(targetKg);
    if (range != null) return range;
    final current = _currentKg;
    if (current == null) return null;
    if (goal == GoalType.lose && targetKg >= current) {
      return 'Pick a target below your current weight.';
    }
    if (goal == GoalType.buildMuscle && targetKg < current) {
      return 'Pick a target at or above your current weight.';
    }
    return null;
  }

  void _pickGoal(GoalType goal) {
    setState(() {
      _goal = goal;
      _showErrors = false;
      // Keep the picked target when it still fits the new goal.
      if (_errorFor(goal, _targetKg) != null) {
        _target = _inUnit(_suggestedKg(goal));
      }
    });
  }

  /// "0.5 kg a week · about 3 months".
  String _paceLine() {
    final perWeek = _unit.fromKg(_pace.kgPerWeek);
    final amount =
        '${perWeek == perWeek.roundToDouble() ? perWeek.round() : perWeek.toStringAsFixed(1)} '
        '$_code a week';
    final current = _currentKg;
    if (current == null || _errorFor(_goal, _targetKg) != null) return amount;
    final weeks = ((_targetKg - current).abs() / _pace.kgPerWeek).ceil();
    if (weeks == 0) return amount;
    final time = weeks < 8
        ? '$weeks ${weeks == 1 ? 'week' : 'weeks'}'
        : '${(weeks / CalculateCalorieGoal.weeksPerMonth).round()} months';
    return '$amount · about $time';
  }

  String get _note => _goal == GoalType.maintain
      ? "We'll set a daily calorie goal that keeps your weight steady, "
            'from your height, age and activity.'
      : "Your daily calorie goal comes next, once we know how active you "
            'are. A steady pace is easier to keep.';

  @override
  Future<bool> submit() async {
    final maintain = _goal == GoalType.maintain;
    if (!maintain && _errorFor(_goal, _targetKg) != null) {
      setState(() => _showErrors = true);
      return false;
    }
    final cubit = context.read<OnboardingCubit>();
    final state = cubit.state;
    final current = _currentKg;
    final months = (maintain || current == null)
        ? 0
        : CalculateCalorieGoal.monthsToTarget(
            currentKg: current,
            targetKg: _targetKg,
            pace: _pace,
          );
    final target = _target == _target.roundToDouble()
        ? '${_target.round()}'
        : _target.toStringAsFixed(1);
    await cubit.updateGoals(
      goalType: _goal.id,
      weeklyPace: maintain ? '' : _pace.id,
      targetWeight: maintain ? state.weight : target,
      targetWeightUnit: maintain ? state.weightUnit : _code,
      goalDurationMonths: '$months',
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final showTarget = _goal != GoalType.maintain;
    final error = _showErrors ? _errorFor(_goal, _targetKg) : null;
    var i = widget.revealFrom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in GoalType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
            child: OnboardingReveal(
              index: i++,
              child: OnboardingChoiceTile(
                title: _goalLabel(goal),
                subtitle: _goalSubtitle(goal),
                icon: Icon(_goalIcon(goal)),
                selected: _goal == goal,
                onTap: () => _pickGoal(goal),
              ),
            ),
          ),
        AnimatedSize(
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppDurations.medium,
            child: showTarget
                ? Column(
                    key: const ValueKey('target'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppDimens.space12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const OnboardingSectionLabel('Target weight'),
                            OnboardingReadout(
                              parts: [(_target.toStringAsFixed(1), _code)],
                              caption: _currentKg == null
                                  ? null
                                  : 'Now ${_unit.fromKg(_currentKg!).toStringAsFixed(1)} $_code',
                            ),
                            const SizedBox(height: AppDimens.space16),
                            ValueRuler(
                              value: _target,
                              min: _unit.minValue.toDouble(),
                              max: _unit.maxValue.toDouble(),
                              step: 0.5,
                              majorEvery: 10,
                              midEvery: 2,
                              color: TrackerMetric.weight.color,
                              semanticValue: (v) =>
                                  '${v.toStringAsFixed(1)} $_code',
                              onChanged: (v) => setState(() {
                                _target = v;
                                _showErrors = false;
                              }),
                            ),
                            OnboardingErrorText(
                              error,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimens.sectionGap),
                            const OnboardingSectionLabel('Weekly pace'),
                            AppSegmentedControl<WeeklyPace>(
                              values: WeeklyPace.values,
                              selected: _pace,
                              label: _paceName,
                              onChanged: (p) => setState(() => _pace = p),
                            ),
                            const SizedBox(height: AppDimens.space8),
                            AnimatedSwitcher(
                              duration: AppDurations.fast,
                              child: Text(
                                _paceLine(),
                                key: ValueKey(_paceLine()),
                                textAlign: TextAlign.center,
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.vColors.grayText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox(key: ValueKey('none'), width: double.infinity),
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        OnboardingReveal(
          index: i++,
          child: AppInfoNote(message: _note),
        ),
      ],
    );
  }

  static String _goalLabel(GoalType goal) => switch (goal) {
    GoalType.lose => 'Lose weight',
    GoalType.maintain => 'Maintain weight',
    GoalType.buildMuscle => 'Build muscle',
  };

  static String _goalSubtitle(GoalType goal) => switch (goal) {
    GoalType.lose => 'A gentle calorie deficit',
    GoalType.maintain => 'Eat for the weight you are',
    GoalType.buildMuscle => 'A small surplus to grow stronger',
  };

  static IconData _goalIcon(GoalType goal) => switch (goal) {
    GoalType.lose => Icons.trending_down_rounded,
    GoalType.maintain => Icons.balance_rounded,
    GoalType.buildMuscle => Icons.fitness_center_rounded,
  };

  static String _paceName(WeeklyPace pace) => switch (pace) {
    WeeklyPace.relaxed => 'Relaxed',
    WeeklyPace.normal => 'Steady',
    WeeklyPace.aggressive => 'Fast',
  };
}
