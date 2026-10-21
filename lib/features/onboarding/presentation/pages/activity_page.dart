import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';

/// One activity level. [value] is saved and mapped to an activity factor
/// by `CalculateCalorieGoal`, so it never changes with the copy.
class ActivityOption {
  final String iconPath;
  final String value;
  final String subtitle;

  const ActivityOption(this.iconPath, this.value, this.subtitle);
}

/// Step 6: how much the user moves on a normal day.
class ActivityStep extends StatefulWidget {
  final int revealFrom;

  const ActivityStep({super.key, this.revealFrom = 3});

  static const options = [
    ActivityOption(
      'assets/icons/onboarding/resting.svg',
      'Mostly resting',
      'Desk job, little exercise',
    ),
    ActivityOption(
      'assets/icons/onboarding/light.svg',
      'Light movement',
      'Walks or light exercise 1-3 days a week',
    ),
    ActivityOption(
      'assets/icons/onboarding/moderate.svg',
      'Moderate activity',
      'Exercise 3-5 days a week',
    ),
    ActivityOption(
      'assets/icons/onboarding/active.svg',
      'Very active',
      'Hard exercise or a physical job most days',
    ),
  ];

  @override
  State<ActivityStep> createState() => _ActivityStepState();
}

class _ActivityStepState extends State<ActivityStep> with OnboardingStepState {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final saved = context.read<OnboardingCubit>().state.activity;
    final index = ActivityStep.options.indexWhere((o) => o.value == saved);
    if (index != -1) _selected = index;
  }

  @override
  Future<bool> submit() async {
    await context.read<OnboardingCubit>().updateHealthVitals(
      activity: ActivityStep.options[_selected].value,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const options = ActivityStep.options;
    final glyph = AppIconBadge.glyphColor(context, context.colors.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
            child: OnboardingReveal(
              index: widget.revealFrom + i,
              child: OnboardingChoiceTile(
                title: options[i].value,
                subtitle: options[i].subtitle,
                icon: SvgPicture.asset(
                  options[i].iconPath,
                  width: AppDimens.iconMd,
                  height: AppDimens.iconMd,
                  colorFilter: ColorFilter.mode(glyph, BlendMode.srcIn),
                ),
                selected: _selected == i,
                onTap: () => setState(() => _selected = i),
              ),
            ),
          ),
        const SizedBox(height: AppDimens.space4),
        OnboardingReveal(
          index: widget.revealFrom + options.length,
          child: const AppInfoNote(
            message:
                'Think of a normal week. There is no right or wrong answer, '
                'and you can change it later.',
          ),
        ),
      ],
    );
  }
}
