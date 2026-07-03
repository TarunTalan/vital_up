import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class OxLevelPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const OxLevelPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<OxLevelPage> createState() => _OxLevelPageState();
}

class _OxLevelPageState extends State<OxLevelPage> {
  int? oxygenLevel;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    if (state.oxygenLevel.isNotEmpty) {
      oxygenLevel = int.tryParse(state.oxygenLevel);
    } else {
      oxygenLevel = 98;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 6,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        context.read<OnboardingCubit>().updateOxygenLevel(oxygenLevel?.toString() ?? '');
        widget.onNext?.call();
      },
      title: "Let’s check your oxygen level",
      subtitle: "This tells us how well your body is getting oxygen.",
      nextEnabled: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          OnboardingNumberField<int>(
            value: oxygenLevel,
            min: 0,
            max: 100,
            onValueChange: (newValue) {
              setState(() {
                if (newValue != null) {
                  oxygenLevel = newValue.clamp(0, 100);
                } else {
                  oxygenLevel = null;
                }
              });
            },
          ),
          const SizedBox(height: OnboardingStyle.sectionSpacingLarge),
          
          SizedBox(
            width: OnboardingStyle.numberFieldWidth + OnboardingStyle.numberFieldHeight,
            height: OnboardingStyle.numberFieldWidth + OnboardingStyle.numberFieldHeight,
            child: const AnimatedLungsIcon(),
          ),
          
          const SizedBox(height: OnboardingStyle.sectionSpacingLarge),
          
          const NoteRow(
            text: "This shows how much oxygen is in your blood. It’s usually checked using a small finger device.",
          ),
        ],
      ),
    );
  }
}

class AnimatedLungsIcon extends StatefulWidget {
  const AnimatedLungsIcon({super.key});

  @override
  State<AnimatedLungsIcon> createState() => _AnimatedLungsIconState();
}

class _AnimatedLungsIconState extends State<AnimatedLungsIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // A slow, deep breathing rhythm (3 seconds per inhale/exhale)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.10).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine, // Very smooth, natural breathing curve
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: SvgPicture.asset(
        'assets/icons/lungs.svg',
        fit: BoxFit.contain,
        width: 162,
        height: 162,
      ),
    );
  }
}
