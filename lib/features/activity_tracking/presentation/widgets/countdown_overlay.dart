import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Full-screen animated 3-2-1 countdown overlay shown before a workout starts.
///
/// Call [CountdownOverlay.show] and await it — it resolves after the countdown
/// finishes so the caller can dispatch [StartTracking] immediately after.
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
      // Short delay so the last number finishes animating before popping.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onFinished();
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
    if (!_finishedNaturally) {
      _tts.stop();
    }
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
