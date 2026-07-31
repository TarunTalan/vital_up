import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vital_up/core/theme/app_theme.dart';


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
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
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
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.72),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top label (no button here anymore) ───────────────────────
            const SizedBox(height: 16),
            // ── Centre: animated count ────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) {
                        return Opacity(
                          opacity: _opacityAnim.value,
                          child: Transform.scale(
                            scale: _scaleAnim.value,
                            child: Text(
                              '$_count',
                              style: const TextStyle(
                                fontSize: 160,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'GET READY',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom: +10 sec & Skip buttons ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CountdownButton(
                    label: '+10 sec',
                    icon: Icons.add_circle_outline_rounded,
                    onTap: _addTen,
                    filled: true,
                    wide: true,
                  ),
                  const SizedBox(height: 12),
                  _CountdownButton(
                    label: 'Skip',
                    icon: Icons.skip_next_rounded,
                    onTap: _skip,
                    filled: false,
                    wide: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper button widget ────────────────────────────────────────────────────

class _CountdownButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool wide;

  const _CountdownButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();
    final textColor = filled ? (customColors?.buttonText ?? Colors.black) : Colors.white;

    final content = Row(
      mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: textColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: content,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: content,
      ),
    );
  }
}

