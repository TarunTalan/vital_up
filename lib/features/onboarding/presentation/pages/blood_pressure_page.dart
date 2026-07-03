import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class BloodPressurePage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const BloodPressurePage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  int? topBp;
  int? bottomBp;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    if (state.bloodPressureTop.isNotEmpty) {
      topBp = int.tryParse(state.bloodPressureTop);
    } else {
      topBp = 120;
    }
    
    if (state.bloodPressureBottom.isNotEmpty) {
      bottomBp = int.tryParse(state.bloodPressureBottom);
    } else {
      bottomBp = 80;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 5,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        context.read<OnboardingCubit>().updateHealthVitals(
          bpTop: topBp?.toString() ?? '',
          bpBottom: bottomBp?.toString() ?? '',
        );
        widget.onNext?.call();
      },
      title: "Let’s check your blood pressure",
      subtitle: "This helps us understand how smoothly blood flows in your body.",
      nextEnabled: true,
      child: Column(
        children: [

          
          // Blood Pressure Inputs (reusable fields)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  OnboardingNumberField<int>(
                    value: topBp,
                    min: 40,
                    max: 250,
                    onValueChange: (val) {
                      setState(() {
                        topBp = val;
                      });
                    },
                    showButtons: false,
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    "Top number",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: OnboardingStyle.sectionSpacingMedium),
              
              Column(
                children: [
                  OnboardingNumberField<int>(
                    value: bottomBp,
                    min: 20,
                    max: 200,
                    onValueChange: (val) {
                      setState(() {
                        bottomBp = val;
                      });
                    },
                    showButtons: false,
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    "Bottom number",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: OnboardingStyle.sectionSpacingLarge),
          
          // Heart Icon - switch to dark SVG in dark mode
          _buildHeartIcon(context),
          
          const SizedBox(height: OnboardingStyle.sectionSpacingLarge),
          
          // note
          const NoteRow(
            text: "These are two numbers usually written together when your pressure is checked.",
          ),
        ],
      ),
    );
  }

  Widget _buildHeartIcon(BuildContext context) {
    // Both light and dark modes use the same SVG for now, unless you have a specific dark SVG
    return SvgPicture.asset(
      'assets/icons/heart_icon.svg',
      width: 162,
      height: 162,
      fit: BoxFit.contain,
    );
  }
}
