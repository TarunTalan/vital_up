import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class ActivityOption {
  final String iconPath;
  final String title;

  const ActivityOption(this.iconPath, this.title);
}

class ActivityPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const ActivityPage({super.key, this.onNext, this.onBack, this.onSkip});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int selectedIndex = 0;

  final List<ActivityOption> options = const [
    ActivityOption('assets/icons/resting.svg', 'Mostly resting'),
    ActivityOption('assets/icons/light.svg', 'Light movement'),
    ActivityOption('assets/icons/moderate.svg', 'Moderate activity'),
    ActivityOption('assets/icons/active.svg', 'Very active'),
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    if (state.activity.isNotEmpty) {
      final index = options.indexWhere((o) => o.title == state.activity);
      if (index != -1) {
        selectedIndex = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 7,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        context.read<OnboardingCubit>().updateHealthVitals(
          activity: options[selectedIndex].title,
        );
        widget.onNext?.call();
      },
      title: "How active are you usually?",
      subtitle:
          "This helps us suggest goals that feel right for your daily life.",
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
                leading: SvgPicture.asset(
                  option.iconPath,
                  width: AppDimens.iconXl,
                  height: AppDimens.iconXl,
                  colorFilter: ColorFilter.mode(
                    context.colors.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
              ),
            );
          }),
          const SizedBox(height: AppDimens.space16),
          const NoteRow(
            text:
                "This just tells us how much you usually move in a normal day. There is no right or wrong answer.",
          ),
        ],
      ),
    );
  }
}
