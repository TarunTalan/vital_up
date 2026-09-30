import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class DietaryOption {
  final String title;
  const DietaryOption(this.title);
}

class DietaryPreferencePage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const DietaryPreferencePage({super.key, this.onNext, this.onBack, this.onSkip});

  @override
  State<DietaryPreferencePage> createState() => _DietaryPreferencePageState();
}

class _DietaryPreferencePageState extends State<DietaryPreferencePage> {
  int selectedIndex = 0;

  final List<DietaryOption> options = const [
    DietaryOption('No specific preference'),
    DietaryOption('Vegetarian'),
    DietaryOption('Vegan'),
    DietaryOption('Keto'),
    DietaryOption('Paleo'),
    DietaryOption('Halal'),
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    if (state.dietaryPreference.isNotEmpty) {
      final index = options.indexWhere((o) => o.title == state.dietaryPreference);
      if (index != -1) {
        selectedIndex = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 4,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        context.read<OnboardingCubit>().updateHealthVitals(
          dietaryPreference: options[selectedIndex].title,
        );
        widget.onNext?.call();
      },
      title: "Dietary preferences",
      subtitle: "To tailor your diet plan accurately.",
      nextEnabled: true,
      child: Column(
        children: [
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.space16),
              child: OnboardingOptionTile(
                label: option.title,
                isSelected: selectedIndex == index,
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
