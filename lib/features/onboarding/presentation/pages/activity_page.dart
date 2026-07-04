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

  const ActivityPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

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
        context.read<OnboardingCubit>().updateHealthVitals(activity: options[selectedIndex].title);
        widget.onNext?.call();
      },
      title: "How active are you usually?",
      subtitle: "This helps us suggest goals that feel right for your daily life.",
      nextEnabled: true,
      titleBottomSpace: 16.0,
      child: Column(
        children: [

          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.only(
                bottom: OnboardingStyle.sectionSpacingMedium,
              ),
              child: _buildActivityOptionCard(
                option: option,
                isSelected: isSelected,
                onClick: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                context: context,
              ),
            );
          }),
          
          const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
          
          const NoteRow(
            text: "This just tells us how much you usually move in a normal day. There is no right or wrong answer.",
          ),
        ],
      ),
    );
  }

  Widget _buildActivityOptionCard({
    required ActivityOption option,
    required bool isSelected,
    required VoidCallback onClick,
    required BuildContext context,
  }) {
    const brandColor = Color.fromRGBO(25, 195, 224, 1.0);
    final activeColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onClick,
      borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? null : OnboardingColors.fieldBackground,
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    brandColor.withOpacity(0.08),
                    brandColor.withOpacity(0.7),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
          border: Border.all(
            color: isSelected ? brandColor.withOpacity(0.27) : OnboardingColors.fieldBorder,
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OnboardingStyle.screenHorizontalPadding,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  option.iconPath,
                  width: 26, // Reduced size
                  height: 26,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: OnboardingStyle.sectionSpacingSmall),
                Text(
                  option.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
