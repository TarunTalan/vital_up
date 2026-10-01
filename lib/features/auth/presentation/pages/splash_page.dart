import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';

/// Splash — Figma "splash screen animation" (57:139):
/// 1. Launch: the cyan head circle drops in from above.
/// 2. It lands, and the logo body (arch + heart) blooms out behind it.
/// 3. The circle grows until the whole screen is cyan.
/// 4. Tagline: the fill deepens to teal and the white tagline fades in.
/// Then the page fades out and routes on the session state.
///
/// Logo geometry uses the 500x500 viewBox of `logo_bottom.svg`.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 3000;

  // Logo viewBox geometry (500x500 space).
  static const double _viewBox = 500.0;
  static const double _circleLeft = 175.0;
  static const double _circleTop = 70.0;
  static const double _circleSize = 150.0;
  static const Alignment _circleCenter = Alignment(0.0, -0.42);

  static Interval _interval(int startMs, int endMs, Curve curve) =>
      Interval(startMs / _totalMs, endMs / _totalMs, curve: curve);

  late final AnimationController _controller;
  late final Animation<double> _dropProgress;
  late final Animation<double> _dropRotation;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;
  late final Animation<double> _logoBottomScale;
  late final Animation<double> _logoBottomOpacity;
  late final Animation<double> _fillProgress;
  late final Animation<double> _tealProgress;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _taglineTranslationY;
  late final Animation<double> _exitOpacity;

  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    _dropProgress = CurvedAnimation(
      parent: _controller,
      curve: _interval(0, 800, Curves.easeOutBack),
    );
    _dropRotation = Tween<double>(begin: -0.18, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _interval(0, 800, Curves.easeOutCubic),
      ),
    );
    _rippleScale = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _interval(800, 1300, Curves.easeOut),
      ),
    );
    _rippleOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _interval(800, 1300, Curves.easeOut),
      ),
    );
    _logoBottomScale = CurvedAnimation(
      parent: _controller,
      curve: _interval(800, 1450, Curves.easeOutBack),
    );
    _logoBottomOpacity = CurvedAnimation(
      parent: _controller,
      curve: _interval(800, 1450, Curves.easeOut),
    );
    _fillProgress = CurvedAnimation(
      parent: _controller,
      curve: _interval(1650, 2100, Curves.easeInCubic),
    );
    _tealProgress = CurvedAnimation(
      parent: _controller,
      curve: _interval(2100, 2400, Curves.easeOut),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: _interval(2150, 2550, Curves.easeOut),
    );
    _taglineTranslationY = Tween<double>(begin: AppDimens.space16, end: 0.0)
        .animate(
      CurvedAnimation(
        parent: _controller,
        curve: _interval(2150, 2550, Curves.easeOut),
      ),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _interval(2750, _totalMs, Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        setState(() => _animationCompleted = true);
        _checkSessionAndNavigate();
      }
    });
  }

  bool _navigating = false;

  Future<void> _checkSessionAndNavigate() async {
    if (!mounted || !_animationCompleted || _navigating) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is AuthInitial || authState is AuthLoading) {
      // Session check not complete yet. Wait for state change.
      return;
    }

    _navigating = true;
    if (authState is AuthAuthenticated) {
      final completed = await context.read<AuthCubit>().hasCompletedOnboarding();
      if (!mounted) return;
      context.goNamed(completed ? 'dashboard' : 'health-onboarding');
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
    final backgroundColor = context.colors.surface;
    final showLoaderAfterSplash = _animationCompleted &&
        (authState is AuthInitial || authState is AuthLoading);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        _checkSessionAndNavigate();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: showLoaderAfterSplash
            ? const VitalUpLoader()
            : LayoutBuilder(
                builder: (context, constraints) => AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _exitOpacity.value,
                    child: _buildFrame(context, constraints.biggest),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFrame(BuildContext context, Size screen) {
    final logoSize = context.w(AppDimens.splashLogo);
    final unit = logoSize / _viewBox;
    final circleSize = _circleSize * unit;
    final dropY = (-_viewBox + (_viewBox + _circleTop) * _dropProgress.value) * unit;

    // Scale needed for the head circle to cover the whole screen.
    final diagonal = math.sqrt(
      screen.width * screen.width + screen.height * screen.height,
    );
    final fillScale = 1.0 + (2 * diagonal / circleSize) * _fillProgress.value;
    final circleColor =
        Color.lerp(AppColors.primary, AppColors.teal, _tealProgress.value)!;
    final filled = _fillProgress.value > 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Logo + dropping head circle.
        Center(
          child: SizedBox.square(
            dimension: logoSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform.scale(
                    scale: _logoBottomScale.value,
                    alignment: _circleCenter,
                    child: Opacity(
                      opacity: _logoBottomOpacity.value.clamp(0.0, 1.0),
                      child: SvgPicture.asset(
                        'assets/icons/logo_bottom.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _circleLeft * unit,
                  top: _circleTop * unit,
                  width: circleSize,
                  height: circleSize,
                  child: Transform.scale(
                    scale: _rippleScale.value,
                    child: Opacity(
                      opacity: _rippleOpacity.value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: AppDimens.borderThick,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _circleLeft * unit,
                  top: dropY,
                  width: circleSize,
                  height: circleSize,
                  child: Transform.rotate(
                    angle: _dropRotation.value,
                    child: Transform.scale(
                      scale: fillScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                          boxShadow: filled ? null : AppShadows.soft,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tagline on the teal fill.
        if (_taglineOpacity.value > 0.0)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(AppDimens.space40)),
            child: Opacity(
              opacity: _taglineOpacity.value,
              child: Transform.translate(
                offset: Offset(0.0, _taglineTranslationY.value),
                child: Text(
                  'Caring for your health.\nBecause every detail matters.',
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(
                    color: AppColors.lighter,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
