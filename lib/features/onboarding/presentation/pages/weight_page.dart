import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/utils/onboarding_components.dart';

class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  bool _showErrors = false;
  bool _latestValid = true;

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 3,
      onBack: () {
        setState(() => _showErrors = false);
        context.goNamed('health-height');
      },
      onNext: () {
        if (!_latestValid) {
          setState(() {
            _showErrors = true;
          });
        } else {
          context.goNamed('health-dietary-preference');
        }
      },
      onSkip: () {
        setState(() => _showErrors = false);
        context.goNamed('health-dietary-preference');
      },
      title: "Your weight",
      subtitle: "To accurately calculate your BMI.",
      nextEnabled: true,
      fullBleedChild: true,
      titleBottomSpace: AppDimens.space16,
      child: _WeightContent(
        onValidityChange: (valid) {
          // Only rebuild on a real change: an unconditional setState here
          // rebuilt the child, which reported again, every frame.
          if (valid == _latestValid) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && valid != _latestValid) {
              setState(() => _latestValid = valid);
            }
          });
        },
        showErrors: _showErrors,
        onClearError: () {
          setState(() {
            _showErrors = false;
          });
        },
      ),
    );
  }
}

class _WeightContent extends StatefulWidget {
  final ValueChanged<bool> onValidityChange;
  final bool showErrors;
  final VoidCallback onClearError;

  const _WeightContent({
    required this.onValidityChange,
    this.showErrors = false,
    required this.onClearError,
  });

  @override
  State<_WeightContent> createState() => _WeightContentState();
}

class _WeightContentState extends State<_WeightContent> {
  int? _weight = 70;
  String _selectedUnit = "kg";

  @override
  void initState() {
    super.initState();
    final cubit = context.read<OnboardingCubit>();
    if (cubit.state.weight.isNotEmpty) {
      _weight = int.tryParse(cubit.state.weight);
    }
    if (cubit.state.weightUnit.isNotEmpty) {
      _selectedUnit = cubit.state.weightUnit;
    }
  }

  static const _kgPerLb = CalculateCalorieGoal.kgPerLb;

  /// The entered weight in kg, or null while empty.
  double? get _weightKg => _weight == null
      ? null
      : CalculateCalorieGoal.weightInKg('$_weight', _selectedUnit);

  @override
  Widget build(BuildContext context) {
    final isLb = _selectedUnit.toLowerCase() == "lb";
    final minWeight = isLb
        ? (InputLimits.weightKgMin / _kgPerLb).ceil()
        : InputLimits.weightKgMin.round();
    final maxWeight = isLb
        ? (InputLimits.weightKgMax / _kgPerLb).floor()
        : InputLimits.weightKgMax.round();
    final error = ProfileRules.weightError(_weightKg);
    final valid = error == null;
    widget.onValidityChange(valid);

    return Column(
      children: [
        Padding(
          padding: context.pagePadding,
          child: Column(
            children: [
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OnboardingNumberField<int>(
                    value: _weight,
                    onValueChange: (val) {
                      setState(() => _weight = val);
                      // Out-of-range values show an error and aren't saved.
                      if (val != null && ProfileRules.weightError(_weightKg) == null) {
                        context.read<OnboardingCubit>().updateWeight(val.toString(), _selectedUnit);
                      }
                    },
                    min: minWeight,
                    max: maxWeight,
                    showButtons: true,
                    isError: widget.showErrors && !valid,
                  ),
                ],
              ),
              if (widget.showErrors && error != null) ...[
                const SizedBox(height: AppDimens.space8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.error),
                ),
              ],
              const SizedBox(height: AppDimens.space8),
              UnitDropdown(
                selectedUnit: _selectedUnit,
                units: const ["kg", "lb"],
                onUnitSelected: (unit) {
                  setState(() {
                    if (_selectedUnit != unit) {
                      if (unit == "lb" && _weight != null) {
                        _weight = (_weight! / _kgPerLb).round().clamp(
                          (InputLimits.weightKgMin / _kgPerLb).ceil(),
                          (InputLimits.weightKgMax / _kgPerLb).floor(),
                        );
                      } else if (unit == "kg" && _weight != null) {
                        _weight = (_weight! * _kgPerLb).round().clamp(
                          InputLimits.weightKgMin.round(),
                          InputLimits.weightKgMax.round(),
                        );
                      }
                      _selectedUnit = unit;
                    }
                  });
                  if (_weight != null && ProfileRules.weightError(_weightKg) == null) {
                    context.read<OnboardingCubit>().updateWeight(_weight.toString(), unit);
                  }
                },
              ),
              const SizedBox(height: AppDimens.space16),
            ],
          ),
        ),
        
        // Image
        Builder(
          builder: (context) {
            final physicalHeight = context.screenHeight + MediaQuery.viewInsetsOf(context).bottom;
            return SizedBox(
              width: double.infinity,
              height: physicalHeight * 0.28,
              child: SvgPicture.asset(
                'assets/icons/weight.svg',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            );
          }
        ),
      ],
    );
  }
}
