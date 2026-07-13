import 'dart:async';
import 'package:flutter/material.dart';

/// Full-screen animated 3-2-1 countdown overlay shown before a workout starts.
///
/// Call [CountdownOverlay.show] and await it — it resolves after the countdown
/// finishes so the caller can dispatch [StartTracking] immediately after.
class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({super.key});

  /// Pushes a full-screen overlay route and awaits the countdown.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const CountdownOverlay(),
      ),
    );
  }

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
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
  }

  void _tick() {
    if (!mounted) return;
    if (_count <= 1) {
      _ticker?.cancel();
      // Short delay so the last number finishes animating before popping.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    setState(() => _count--);
    _runCount();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      body: Center(
        child: AnimatedBuilder(
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
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
