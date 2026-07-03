import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';

/// A splash screen page that displays a custom brand logo animation
/// matching the Figma specifications, with added modern micro-interactions
/// (bounce landing, ripple pulse, subtle glow, punchier bloom).
///
/// Coordinate Space: Unified 500x500 viewport scaled to fit 220x220.
///
/// Animation Sequence (Total 2800ms — standard splash length):
/// 1. 0ms to 800ms (Drop Phase):
///    The initial circle drops from the top of the screen (off-screen Y=-500)
///    down to its landing position (Y=70) inside the 500x500 box, with a
///    subtle overshoot/bounce on landing and a slight rotational flourish.
/// 2. 800ms to 1500ms (Logo Bottom Phase):
///    The circle remains static in the middle. A soft ripple ring pulses
///    outward from it on landing. The logo_bottom.svg (Arch, Heart & Body)
///    blooms outwards from behind the circle with a gentle pop (scale 0.0
///    to 1.0 with slight overshoot, opacity 0.0 to 1.0) using a transform
///    origin at the circle's center (Alignment(0.0, -0.42)).
/// 3. 1500ms to 2100ms (Tagline Phase):
///    The tagline fades in, scales up slightly, and slides up below the logo.
/// 4. 2100ms to 2400ms: Holds the completed state.
/// 5. 2400ms to 2800ms: Entire page fades out to transition.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Phase 1: Drop (0% to 28.6% of timeline)
  late Animation<double> _dropProgress;
  late Animation<double> _dropRotation;

  // Ripple pulse on landing (28.6% to ~46.4% of timeline)
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  // Phase 2: Logo Bottom Bloom (28.6% to 53.6% of timeline)
  late Animation<double> _logoBottomScale;
  late Animation<double> _logoBottomOpacity;

  // Phase 3: Tagline (53.6% to 75.0% of timeline)
  late Animation<double> _taglineOpacity;
  late Animation<double> _taglineTranslationY;
  late Animation<double> _taglineScale;

  // Phase 5: Exit (85.7% to 100% of timeline)
  late Animation<double> _exitOpacity;

  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    // 2800ms duration — standard app splash screen length
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // 1. Drop Progress: 0.0 to 1.0 (0% to 28.6% of timeline)
    // easeOutBack gives a subtle bounce/overshoot as it lands — feels alive
    // instead of just stopping dead.
    _dropProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 800 / 2800, curve: Curves.easeOutBack),
      ),
    );

    // Subtle rotational flourish while dropping, settles to 0 on landing.
    _dropRotation = Tween<double>(begin: -0.18, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 800 / 2800, curve: Curves.easeOutCubic),
      ),
    );

    // Ripple ring: pulses outward from the circle right as it lands
    _rippleScale = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(800 / 2800, 1300 / 2800, curve: Curves.easeOut),
      ),
    );
    _rippleOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(800 / 2800, 1300 / 2800, curve: Curves.easeOut),
      ),
    );

    // 2. logo_bottom.svg scale & opacity: starts after drop (800ms - 1500ms in 2800ms scale)
    // easeOutBack gives the bloom a gentle "pop" instead of a flat ease-out.
    _logoBottomScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          800 / 2800,
          1500 / 2800,
          curve: Curves.easeOutBack,
        ),
      ),
    );
    _logoBottomOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(800 / 2800, 1500 / 2800, curve: Curves.easeOut),
      ),
    );

    // 3. Tagline Opacity (1500ms - 2100ms in 2800ms scale)
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(1500 / 2800, 2100 / 2800, curve: Curves.easeOut),
      ),
    );

    // 4. Tagline Slide
    _taglineTranslationY = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(1500 / 2800, 2100 / 2800, curve: Curves.easeOut),
      ),
    );

    // Tagline gentle scale-in for a softer, more modern entrance
    _taglineScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(1500 / 2800, 2100 / 2800, curve: Curves.easeOut),
      ),
    );

    // 5. Exit Opacity (2400ms - 2800ms in 2800ms scale)
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(2400 / 2800, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start sequence
    _controller.forward().then((_) {
      if (mounted) {
        setState(() => _animationCompleted = true);
        _checkSessionAndNavigate();
      }
    });
  }

  void _checkSessionAndNavigate() {
    if (!mounted || !_animationCompleted) return;

    final state = context.read<AuthCubit>().state;

    // Do not navigate if database session check is still running
    if (state is AuthInitial || state is AuthLoading) {
      return;
    }

    if (state is AuthAuthenticated) {
      context.goNamed('dashboard');
    } else {
      context.goNamed('onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive scaling based on design width 360
    final double scale = (screenWidth / 360.0).clamp(0.8, 1.2);

    // Base multiplier to scale down the 500x500 viewBox to 220x220
    final double baseScale = 0.44 * scale;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF444444) : Colors.white;
    final taglineColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF444444).withValues(alpha: 0.7);

    // Circle color: white in dark mode (charcoal background) and cyan in light mode (white background)
    final Color circleColor = isDarkMode
        ? Colors.white
        : const Color(0xFF19C3E0);

    // Soft glow accent behind the logo for a bit of modern depth.
    final Color glowColor = const Color(
      0xFF19C3E0,
    ).withValues(alpha: isDarkMode ? 0.08 : 0.10);
    final showLoaderAfterSplash =
        _animationCompleted &&
        (authState is AuthInitial || authState is AuthLoading);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        _checkSessionAndNavigate();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            // Subtle radial glow behind the logo for depth — very understated,
            // just enough to keep a flat background from feeling static.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.05),
                    radius: 0.65,
                    colors: [glowColor, backgroundColor.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
            if (showLoaderAfterSplash)
              const Positioned.fill(child: VitalUpLoader())
            else
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Drop Y coordinate: starts at -500 (off-screen) and lands at Y = 70 inside 500x500 space
                  final double dropY =
                      (-500.0 + (500.0 + 70.0) * _dropProgress.value) *
                      baseScale;

                  return Opacity(
                    opacity: _exitOpacity.value,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // --- Animated Logo Container (500x500 coordinate space) ---
                          SizedBox(
                            width: 500.0 * baseScale,
                            height: 500.0 * baseScale,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 1. logo_bottom.svg (Body, Heart & Arch)
                                // Rendered BEHIND the circle (first in Stack), pinned in its final
                                // position. Stays invisible until the circle lands, then blooms
                                // outwards in place from the circle's center with a gentle pop.
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  width: 500.0 * baseScale,
                                  height: 500.0 * baseScale,
                                  child: Transform.scale(
                                    scale: _logoBottomScale.value,
                                    alignment: const Alignment(
                                      0.0,
                                      -0.42,
                                    ), // Exact center of head circle
                                    child: Opacity(
                                      opacity: _logoBottomOpacity.value,
                                      child: SvgPicture.asset(
                                        'assets/icons/logo_bottom.svg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                // 2. Ripple ring — pulses outward from the circle on landing,
                                // a small modern flourish that adds motion without noise.
                                Positioned(
                                  left: 175.0 * baseScale,
                                  top: 70.0 * baseScale,
                                  width: 150.0 * baseScale,
                                  height: 150.0 * baseScale,
                                  child: Transform.scale(
                                    scale: _rippleScale.value,
                                    child: Opacity(
                                      opacity: _rippleOpacity.value,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: circleColor,
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 3. Dropping Circle
                                // Rendered ON TOP of logo_bottom and the ripple (last in Stack).
                                // Positioned at exact 500x500 coordinates: left: 175, top: dropY, width: 150, height: 150
                                // Falls with a slight rotational flourish and settles with a
                                // gentle overshoot/bounce instead of a hard stop.
                                Positioned(
                                  left: 175.0 * baseScale,
                                  top: dropY,
                                  width: 150.0 * baseScale,
                                  height: 150.0 * baseScale,
                                  child: Transform.rotate(
                                    angle: _dropRotation.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: circleColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: circleColor.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 24.0 * scale,
                                            spreadRadius: 1.0 * scale,
                                            offset: Offset(0, 6.0 * scale),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 15.0 * scale),
                          // --- Animated Tagline ---
                          Opacity(
                            opacity: _taglineOpacity.value,
                            child: Transform.translate(
                              offset: Offset(
                                0.0,
                                _taglineTranslationY.value * scale,
                              ),
                              child: Transform.scale(
                                scale: _taglineScale.value,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: Text(
                                    'Understand Your Body. Elevate Your Health.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: taglineColor,
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
