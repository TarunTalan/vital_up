import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SleepPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const SleepPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  int? sleep;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    if (state.sleep.isNotEmpty) {
      sleep = int.tryParse(state.sleep);
    } else {
      sleep = 8;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 8,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        context.read<OnboardingCubit>().updateHealthVitals(sleep: sleep?.toString() ?? '');
        widget.onNext?.call();
      },
      title: "How much do you usually sleep?",
      subtitle: "This helps us suggest a healthy rest schedule for you.",
      nextEnabled: sleep != null,
      fullBleedChild: true,
      titleBottomSpace: AppDimens.sectionGap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          SvgPicture.asset(
            'assets/icons/sleep.svg',
            width: context.screenWidth,
            fit: BoxFit.fitWidth,
          ),
          
          const SizedBox(height: AppDimens.space32),

          Padding(
            padding: context.pagePadding,
            child: Column(
              children: [

          OnboardingNumberField<int>(
            value: sleep,
            min: 0,
            max: 24,
            onValueChange: (val) {
              setState(() {
                sleep = val;
              });
            },
            showButtons: true,
          ),
          const SizedBox(height: AppDimens.space6),
          const OnboardingFieldCaption("Hours per night"),

          const SizedBox(height: AppDimens.space32),

          // note row
          const NoteRow(
            text: "Just an average guess is fine. It doesn’t have to be exact.",
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
