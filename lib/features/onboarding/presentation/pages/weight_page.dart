import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Step 3: weight on the same sliding scale as the weight log (0.1 steps),
/// in kg or lb, with the BMI it gives once the height is known. Saved only
/// on Continue: a skipped step leaves the weight empty.
class WeightStep extends StatefulWidget {
  final int revealFrom;

  const WeightStep({super.key, this.revealFrom = 3});

  @override
  State<WeightStep> createState() => _WeightStepState();
}

class _WeightStepState extends State<WeightStep> with OnboardingStepState {
  /// 'kg' or 'lb' (what onboarding stores).
  late String _code;

  /// The picked weight in [_unit], one decimal.
  late double _value;
  String? _error;

  WeightUnit get _unit => WeightUnit.fromCode(_code);

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    final savedKg = CalculateCalorieGoal.weightInKg(
      state.weight,
      state.weightUnit,
    );
    if (savedKg != null) {
      _code = WeightUnit.fromCode(state.weightUnit) == WeightUnit.lbs
          ? 'lb'
          : 'kg';
    } else {
      final settings = context.read<SettingsCubit>().state;
      final pounds =
          settings is SettingsLoaded &&
          WeightUnit.fromCode(settings.settings.weightUnit) == WeightUnit.lbs;
      _code = pounds ? 'lb' : 'kg';
    }
    _value = _inUnit(
      savedKg ??
          switch (state.gender.toLowerCase()) {
            'male' => 75,
            'female' => 62,
            _ => 70,
          },
    );
  }

  static double _tenth(double v) => double.parse(v.toStringAsFixed(1));

  double _inUnit(double kg) => _tenth(
    _unit
        .fromKg(kg)
        .clamp(_unit.minValue.toDouble(), _unit.maxValue.toDouble()),
  );

  void _changeUnit(String code) {
    final kg = _unit.toKg(_value);
    setState(() {
      _code = code;
      _value = _inUnit(kg);
      _error = null;
    });
  }

  /// "72" or "72.5".
  static String _format(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  Future<bool> submit() async {
    final error = ProfileRules.weightError(_unit.toKg(_value));
    if (error != null) {
      setState(() => _error = error);
      return false;
    }
    await context.read<OnboardingCubit>().updateWeight(_format(_value), _code);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<OnboardingCubit>().state;
    final bmi = bmiOf(
      kg: _unit.toKg(_value),
      cm: CalculateCalorieGoal.heightInCm(state.height, state.heightUnit),
    );
    var i = widget.revealFrom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingReveal(
          index: i++,
          child: Center(
            child: AppSegmentedControl<String>(
              values: const ['kg', 'lb'],
              selected: _code,
              label: (u) => u,
              onChanged: _changeUnit,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: OnboardingReadout(
            parts: [(_value.toStringAsFixed(1), _code)],
            caption: bmi == null ? null : 'BMI ${bmi.toStringAsFixed(1)}',
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: ValueRuler(
            key: ValueKey(_code),
            value: _value,
            min: _unit.minValue.toDouble(),
            max: _unit.maxValue.toDouble(),
            color: TrackerMetric.weight.color,
            semanticValue: (v) => '${v.toStringAsFixed(1)} $_code',
            onChanged: (v) => setState(() {
              _value = v;
              _error = null;
            }),
          ),
        ),
        OnboardingErrorText(_error, textAlign: TextAlign.center),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: const AppInfoNote(
            message:
                'An estimate is fine. You can log your weight any time '
                'from Home to track the trend.',
          ),
        ),
      ],
    );
  }
}
