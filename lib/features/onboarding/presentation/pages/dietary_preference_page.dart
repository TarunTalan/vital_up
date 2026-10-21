import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';

/// One answer to "How do you eat?". [value] is what's saved and sent to
/// the diet plan AI, so it never changes with the copy.
class DietaryOption {
  final String value;
  final String subtitle;
  final IconData icon;

  const DietaryOption(this.value, this.subtitle, this.icon);
}

/// Step 4: dietary preference, one of [options].
class DietaryPreferenceStep extends StatefulWidget {
  final int revealFrom;

  const DietaryPreferenceStep({super.key, this.revealFrom = 3});

  static const options = [
    DietaryOption(
      'No specific preference',
      'I eat a bit of everything',
      Icons.restaurant_rounded,
    ),
    DietaryOption('Vegetarian', 'No meat or fish', Icons.eco_rounded),
    DietaryOption('Vegan', 'No animal products at all', Icons.spa_rounded),
    DietaryOption('Keto', 'Very low carb, higher fat', Icons.egg_alt_rounded),
    DietaryOption(
      'Paleo',
      'Whole foods, no grains or dairy',
      Icons.set_meal_rounded,
    ),
    DietaryOption(
      'Halal',
      'Prepared under Islamic dietary law',
      Icons.verified_rounded,
    ),
  ];

  @override
  State<DietaryPreferenceStep> createState() => _DietaryPreferenceStepState();
}

class _DietaryPreferenceStepState extends State<DietaryPreferenceStep>
    with OnboardingStepState {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final saved = context.read<OnboardingCubit>().state.dietaryPreference;
    final index = DietaryPreferenceStep.options.indexWhere(
      (o) => o.value == saved,
    );
    if (index != -1) _selected = index;
  }

  @override
  Future<bool> submit() async {
    await context.read<OnboardingCubit>().updateHealthVitals(
      dietaryPreference: DietaryPreferenceStep.options[_selected].value,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const options = DietaryPreferenceStep.options;
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
                icon: Icon(options[i].icon),
                selected: _selected == i,
                onTap: () => setState(() => _selected = i),
              ),
            ),
          ),
      ],
    );
  }
}
