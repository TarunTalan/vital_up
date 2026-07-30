import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';

class OnboardingEntryPoint extends StatefulWidget {
  const OnboardingEntryPoint({super.key});

  @override
  State<OnboardingEntryPoint> createState() => _OnboardingEntryPointState();
}

class _OnboardingEntryPointState extends State<OnboardingEntryPoint> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<OnboardingCubit>().state;
      if (state.currentStep != 'loading') {
        _navigate(state.currentStep);
      }
    });
  }

  void _navigate(String step) {
    if (_hasNavigated || step == 'loading') return;

    String routeName;
    switch (step) {
      case 'personal_details':
        routeName = 'health-personal-details';
        break;
      case 'height':
        routeName = 'health-height';
        break;
      case 'weight':
        routeName = 'health-weight'; 
        break;
      case 'blood_pressure':
        routeName = 'health-blood-pressure';
        break;
      case 'bpm':
        routeName = 'health-bpm';
        break;
      case 'goals':
        routeName = 'health-goals';
        break;
      case 'activity':
        routeName = 'health-activity';
        break;
      case 'info':
        routeName = 'health-info-permission';
        break;
      default:
        routeName = 'health-extra-details';
    }

    _hasNavigated = true;
    context.goNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingCubit, OnboardingData>(
      listenWhen: (previous, current) => previous.currentStep != current.currentStep,
      listener: (context, state) {
        _navigate(state.currentStep);
      },
      child: const Scaffold(
        body: Center(
          child: VitalUpLoader(),
        ),
      ),
    );
  }
}
