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

  const BloodPressurePage({super.key, this.onNext, this.onBack, this.onSkip});

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
      subtitle: "This helps us monitor your cardiovascular health.",
      nextEnabled: true,
      child: Column(
        children: [
          // Blood Pressure Inputs (reusable fields)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: AppDimens.space6),
                  const OnboardingFieldCaption("Top number"),
                ],
              ),

              const SizedBox(width: AppDimens.space16),

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
                  const SizedBox(height: AppDimens.space6),
                  const OnboardingFieldCaption("Bottom number"),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppDimens.space32),

          // Heart Icon - switch to dark SVG in dark mode
          _buildHeartIcon(context),

          const SizedBox(height: AppDimens.space32),

          // note
          const NoteRow(
            text:
                "These are two numbers usually written together when your pressure is checked.",
          ),
        ],
      ),
    );
  }

  Widget _buildHeartIcon(BuildContext context) {
    // Both light and dark modes use the same SVG for now, unless you have a specific dark SVG
    return SvgPicture.asset(
      'assets/icons/heart_icon.svg',
      width: AppDimens.onboardingIllustration,
      height: AppDimens.onboardingIllustration,
      fit: BoxFit.contain,
    );
  }
}
