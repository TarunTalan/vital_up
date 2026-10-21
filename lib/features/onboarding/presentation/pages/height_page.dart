import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';

/// Step 2: height on a sliding scale, in cm or feet and inches. Saved as
/// "170" (cm) or "5-7" (ft-in), what the rest of the app reads.
class HeightStep extends StatefulWidget {
  final int revealFrom;

  const HeightStep({super.key, this.revealFrom = 3});

  @override
  State<HeightStep> createState() => _HeightStepState();
}

class _HeightStepState extends State<HeightStep> with OnboardingStepState {
  static const _cmPerInch = CalculateCalorieGoal.cmPerInch;

  /// The feet scale runs in whole inches from 2 ft, so every label sits on
  /// a whole foot.
  static const _minInches = 24;
  static final _maxInches = (InputLimits.heightCmMax / _cmPerInch).floor();

  late String _unit;

  /// The picked height in cm (whole cm, or a whole number of inches).
  late double _cm;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    final saved = CalculateCalorieGoal.heightInCm(
      state.height,
      state.heightUnit,
    );
    if (saved != null) {
      _unit = state.heightUnit == 'ft' ? 'ft' : 'cm';
    } else {
      // Nothing picked yet: the unit set in Settings, at a typical height.
      final settings = context.read<SettingsCubit>().state;
      final imperial =
          settings is SettingsLoaded && settings.settings.heightUnit == 'in';
      _unit = imperial ? 'ft' : 'cm';
    }
    _cm = _snapToUnit(
      saved ??
          switch (state.gender.toLowerCase()) {
            'male' => 176,
            'female' => 163,
            _ => 170,
          },
    );
  }

  int get _inches => (_cm / _cmPerInch).round();

  double _snapToUnit(double cm) => _unit == 'ft'
      ? (cm / _cmPerInch).round().clamp(_minInches, _maxInches) * _cmPerInch
      : cm.roundToDouble().clamp(
          InputLimits.heightCmMin,
          InputLimits.heightCmMax,
        );

  void _changeUnit(String unit) {
    setState(() {
      _unit = unit;
      _cm = _snapToUnit(_cm);
      _error = null;
    });
  }

  @override
  Future<bool> submit() async {
    final error = ProfileRules.heightError(_cm);
    if (error != null) {
      setState(() => _error = error);
      return false;
    }
    final value = _unit == 'ft'
        ? '${_inches ~/ 12}-${_inches % 12}'
        : '${_cm.round()}';
    await context.read<OnboardingCubit>().updateHeight(value, _unit);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final feet = _unit == 'ft';
    final inches = _inches;
    final parts = feet
        ? [('${inches ~/ 12}', 'ft'), ('${inches % 12}', 'in')]
        : [('${_cm.round()}', 'cm')];
    final other = feet
        ? '${_cm.round()} cm'
        : '${inches ~/ 12} ft ${inches % 12} in';
    var i = widget.revealFrom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingReveal(
          index: i++,
          child: Center(
            child: AppSegmentedControl<String>(
              values: const ['cm', 'ft'],
              selected: _unit,
              label: (u) => u == 'cm' ? 'cm' : 'ft / in',
              onChanged: _changeUnit,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: OnboardingReadout(parts: parts, caption: other),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: feet
              ? ValueRuler(
                  key: const ValueKey('ft'),
                  value: inches.toDouble(),
                  min: _minInches.toDouble(),
                  max: _maxInches.toDouble(),
                  step: 1,
                  majorEvery: 12,
                  midEvery: 6,
                  color: context.colors.primary,
                  labelFor: (v) => '${v.round() ~/ 12} ft',
                  semanticValue: (v) =>
                      '${v.round() ~/ 12} feet ${v.round() % 12} inches',
                  onChanged: (v) => setState(() {
                    _cm = v * _cmPerInch;
                    _error = null;
                  }),
                )
              : ValueRuler(
                  key: const ValueKey('cm'),
                  value: _cm.roundToDouble(),
                  min: InputLimits.heightCmMin,
                  max: InputLimits.heightCmMax,
                  step: 1,
                  color: context.colors.primary,
                  semanticValue: (v) => '${v.round()} centimetres',
                  onChanged: (v) => setState(() {
                    _cm = v;
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
                'Drag the scale or tap a mark. Your height helps us work '
                'out your BMI and daily energy needs.',
          ),
        ),
      ],
    );
  }
}
