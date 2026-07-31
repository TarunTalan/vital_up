import 'package:flutter/material.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BpmPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const BpmPage({super.key, this.onNext, this.onBack, this.onSkip});

  @override
  State<BpmPage> createState() => _BpmPageState();
}

class _BpmPageState extends State<BpmPage> {
  int? bpm;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    if (state.bpm.isNotEmpty) {
      bpm = int.tryParse(state.bpm);
    } else {
      bpm = 72;
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
          bpm: bpm?.toString() ?? '',
        );
        widget.onNext?.call();
      },
      title: "Let’s check your heart",
      subtitle: "This helps us understand your baseline and track trends.",
      nextEnabled: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OnboardingNumberField<int>(
            value: bpm,
            min: 20,
            max: 300,
            onValueChange: (val) {
              setState(() {
                bpm = val;
              });
            },
          ),
          const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
          Text(
            "Beats per minute",
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: OnboardingStyle.sectionSpacingLarge),

          SizedBox(
            width:
                OnboardingStyle.numberFieldWidth +
                OnboardingStyle.numberFieldHeight,
            height:
                OnboardingStyle.numberFieldWidth +
                OnboardingStyle.numberFieldHeight,
            child: const HeartAnimation(),
          ),

          const SizedBox(height: OnboardingStyle.sectionSpacingLarge),

          const NoteRow(
            text:
                "This is the number of times your heart beats in one minute when you are calm and relaxed.",
          ),
        ],
      ),
    );
  }
}

class HeartAnimation extends StatefulWidget {
  const HeartAnimation({super.key});

  @override
  State<HeartAnimation> createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _glowRadiusAnimation;
  late Animation<double> _glowOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // Slightly faster heartbeat
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic, // Smooth ease in and out for everything
    );

    // More subtle scale (shrinks slightly less, expands slightly less)
    _heartScaleAnimation = Tween<double>(begin: 1.95, end: 2.15).animate(curve);
    // Glow expands much more outward
    _glowRadiusAnimation = Tween<double>(begin: 0.35, end: 0.80).animate(curve);
    // Glow vanishes (0.0) when shrunk, fully opaque (1.0) when enlarged
    _glowOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imagePath = isDark
        ? 'assets/icons/heart.svg'
        : 'assets/icons/heart.svg';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background glow layer
            Positioned.fill(
              child: CustomPaint(
                painter: _GlowPainter(
                  radiusMultiplier: _glowRadiusAnimation.value,
                  opacity: _glowOpacityAnimation.value,
                ),
              ),
            ),
            // Foreground heart layer (scales up and down)
            Transform.scale(scale: _heartScaleAnimation.value, child: child),
          ],
        );
      },
      child: SvgPicture.asset(
        imagePath,
        fit: BoxFit.contain,
        width: 162,
        height: 162,
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final double radiusMultiplier;
  final double opacity;

  _GlowPainter({required this.radiusMultiplier, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return; // Vanish completely when shrunk

    final center = Offset(size.width / 2, size.height / 2);
    final minDimension = size.shortestSide;
    final drawRadius = minDimension * radiusMultiplier;

    if (drawRadius <= 0) return;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          // Use the raw opacity value (hits 1.0 fully when enlarged)
          const Color(0xFFFF3DBF).withValues(alpha: opacity),
          const Color(
            0xFFFF6FD8,
          ).withValues(alpha: opacity * 0.3), // Lighter midway
          const Color(0x00FFD6F1), // Fade to transparent
        ],
        stops: const [0.0, 0.35, 1.0], // Starts fading much earlier
      ).createShader(Rect.fromCircle(center: center, radius: drawRadius));

    canvas.drawCircle(center, drawRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.radiusMultiplier != radiusMultiplier ||
        oldDelegate.opacity != opacity;
  }
}
