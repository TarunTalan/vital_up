import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
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
          context.goNamed('health-bpm');
        }
      },
      onSkip: () {
        setState(() => _showErrors = false);
        context.goNamed('health-bpm');
      },
      title: "How much do you weigh?",
      subtitle: "This helps us calculate your BMI accurately.",
      nextEnabled: true,
      fullBleedChild: true,
      titleBottomSpace: 16.0,
      child: _WeightContent(
        onValidityChange: (valid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _latestValid = valid;
              });
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

  @override
  Widget build(BuildContext context) {
    final minWeight = 10;
    final maxWeight = _selectedUnit.toLowerCase() == "lb" ? 800 : 400;

    final valid = _weight != null;
    widget.onValidityChange(valid);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
          child: Column(
            children: [
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OnboardingNumberField<int>(
                    value: _weight,
                    onValueChange: (val) {
                      final newValue = val ?? minWeight;
                      setState(() => _weight = newValue);
                      context.read<OnboardingCubit>().updateWeight(newValue.toString(), _selectedUnit);
                    },
                    min: minWeight,
                    max: maxWeight,
                    showButtons: true,
                    isError: widget.showErrors && !valid,
                  ),
                ],
              ),
              const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
              UnitDropdown(
                selectedUnit: _selectedUnit,
                units: const ["kg", "lb"],
                onUnitSelected: (unit) {
                  setState(() {
                    if (_selectedUnit != unit) {
                      if (unit == "lb" && _weight != null) {
                        _weight = (_weight! * 2.20462).round().clamp(22, 880);
                      } else if (unit == "kg" && _weight != null) {
                        _weight = (_weight! / 2.20462).round().clamp(10, 400);
                      }
                      _selectedUnit = unit;
                    }
                  });
                  if (_weight != null) {
                    context.read<OnboardingCubit>().updateWeight(_weight.toString(), unit);
                  }
                },
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
        
        // Image
        Builder(
          builder: (context) {
            final physicalHeight = MediaQuery.of(context).size.height + MediaQuery.of(context).viewInsets.bottom;
            return SizedBox(
              width: double.infinity,
              height: physicalHeight * 0.28, // Reduced from 35% to 28% to prevent scrolling
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
