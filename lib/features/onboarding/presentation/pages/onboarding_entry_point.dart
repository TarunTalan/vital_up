import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/onboarding_step.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/pages/onboarding_flow_page.dart';

/// `health-onboarding`: reloads the saved answers (they belong to whoever
/// is signed in now), then opens the flow at the step that was left.
class OnboardingEntryPoint extends StatefulWidget {
  const OnboardingEntryPoint({super.key});

  @override
  State<OnboardingEntryPoint> createState() => _OnboardingEntryPointState();
}

class _OnboardingEntryPointState extends State<OnboardingEntryPoint> {
  /// Fixed once the answers are loaded, so later step changes (saved as
  /// the user moves on) don't rebuild the flow from another step.
  OnboardingStep? _start;

  @override
  void initState() {
    super.initState();
    context.read<OnboardingCubit>().reload();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingData>(
      buildWhen: (_, current) => _start == null,
      builder: (context, state) {
        if (_start == null && state.currentStep != 'loading') {
          _start = OnboardingStep.fromId(state.currentStep);
        }
        final start = _start;
        if (start == null) {
          return const AppScaffold(body: Center(child: VitalUpLoader()));
        }
        return OnboardingFlowPage(initialStep: start);
      },
    );
  }
}
