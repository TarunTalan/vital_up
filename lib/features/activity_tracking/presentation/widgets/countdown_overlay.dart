import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// Full-screen animated countdown overlay shown before a workout starts.
///
/// Features:
///  • Animated scale + fade number display
///  • **+10** button — adds 10 seconds to the remaining countdown
///  • **Skip** button — immediately fires [onFinished]
class CountdownOverlay extends StatefulWidget {
  final int durationSeconds;
  final bool voiceCoachEnabled;
  final VoidCallback onFinished;

  const CountdownOverlay({
    super.key,
    required this.durationSeconds,
    required this.voiceCoachEnabled,
    required this.onFinished,
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late int _count;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  Timer? _ticker;
  final FlutterTts _tts = FlutterTts();
  bool _finishedNaturally = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _count = widget.durationSeconds;
    _tts.setSpeechRate(0.55);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(
      begin: 0.5,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _runCount();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _runCount() {
    _controller.reset();
    _controller.forward();
    if (widget.voiceCoachEnabled && _count <= 3 && _count >= 1) {
      _tts.speak('$_count');
    }
  }

  void _tick() {
    if (!mounted) return;
    if (_count <= 1) {
      _ticker?.cancel();
      _finishedNaturally = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onFinished();
      });
      return;
    }
    setState(() => _count--);
    _runCount();
  }

  /// Adds 10 seconds to the remaining count (max 1000) and restarts the animation.
  void _addTen() {
    HapticFeedback.lightImpact();
    _ticker?.cancel();
    setState(() => _count = (_count + 10).clamp(0, 1000));
    _controller.reset();
    _controller.forward();
    // Restart the periodic ticker from now
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Immediately skips to the start of the workout.
  void _skip() {
    HapticFeedback.mediumImpact();
    _ticker?.cancel();
    _tts.stop();
    _skipped = true;
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    if (!_finishedNaturally && !_skipped) {
      _tts.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const onScrim = AppColors.white;
    return Scaffold(
      backgroundColor: AppColors.black.withValues(alpha: 0.72),
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            children: [
              const SizedBox(height: AppDimens.space16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (_, _) {
                          return Opacity(
                            opacity: _opacityAnim.value,
                            child: Transform.scale(
                              scale: _scaleAnim.value,
                              child: SizedBox(
                                height: context.hFraction(0.18),
                                child: FittedBox(
                                  child: Text(
                                    '$_count',
                                    style: AppTextStyles.largeTitle.copyWith(
                                      color: onScrim,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppDimens.space12),
                      AppCaption(
                        'Get ready',
                        color: onScrim.withValues(alpha: 0.54),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  0,
                  context.gutter,
                  AppDimens.space32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppPrimaryButton(
                      label: '+10 sec',
                      leadingIcon: const Icon(Icons.add_circle_outline_rounded),
                      onTap: _addTen,
                    ),
                    const SizedBox(height: AppDimens.space12),
                    AppSecondaryButton(
                      label: 'Skip',
                      leadingIcon: const Icon(Icons.skip_next_rounded),
                      onTap: _skip,
                      contentColor: onScrim,
                      containerColor: onScrim.withValues(alpha: 0.15),
                      borderColor: onScrim.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
