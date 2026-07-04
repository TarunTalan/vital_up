import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedTick extends StatefulWidget {
  final double totalSize;
  final double tickSize;
  final bool play;
  final bool completed;
  final VoidCallback? onFinished;

  const AnimatedTick({
    super.key,
    this.totalSize = 115.0,
    this.tickSize = 55.0,
    this.play = true,
    this.completed = false,
    this.onFinished,
  });

  @override
  State<AnimatedTick> createState() => _AnimatedTickState();
}

class _AnimatedTickState extends State<AnimatedTick>
    with SingleTickerProviderStateMixin {
  static const _rotationStart = 0.58;

  late final AnimationController _controller;
  late final Animation<double> _tickAndCircleProgress;
  late final Animation<double> _flipProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _tickAndCircleProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Cubic(0.42, 0.0, 0.58, 1.0)),
    );

    _flipProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        _rotationStart,
        1.0,
        curve: Cubic(0.42, 0.0, 0.58, 1.0),
      ),
    );

    if (widget.completed) {
      _controller.value = 1.0;
    } else if (widget.play) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed != oldWidget.completed && widget.completed) {
      _controller.value = 1.0;
      return;
    }

    if (widget.play != oldWidget.play) {
      if (widget.play) {
        _startAnimation();
      } else {
        _resetAnimation();
      }
    }
  }

  void _startAnimation() {
    _controller
      ..reset()
      ..forward().then((_) {
        if (!mounted) return;
        widget.onFinished?.call();
      });
  }

  void _resetAnimation() {
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.totalSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final tickProgress = _tickAndCircleProgress.value;
          final flipProgress = _flipProgress.value;
          final tickWidth = _lerp(
            widget.tickSize * (107.0 / 61.0),
            widget.tickSize,
            tickProgress,
          );
          final tickHeight = tickWidth * (79.0 / 112.0);
          final outerSize = _lerp(
            widget.totalSize * (8.0 / 132.0),
            widget.totalSize,
            tickProgress,
          );
          final innerSize = widget.totalSize * (100.0 / 132.0);
          final flipAngle = math.pi * flipProgress;
          final showInnerCircle = _controller.value >= _rotationStart;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(flipAngle),
                child: SvgPicture.asset(
                  'assets/icons/outercircle.svg',
                  width: outerSize,
                  height: outerSize,
                ),
              ),
              if (showInnerCircle)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(flipAngle),
                  child: SvgPicture.asset(
                    'assets/icons/innercircle.svg',
                    width: innerSize,
                    height: innerSize,
                  ),
                ),
              SizedBox(
                width: tickWidth,
                height: tickHeight,
                child: SvgPicture.asset(
                  'assets/icons/tick.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _lerp(double begin, double end, double progress) {
    return begin + (end - begin) * progress;
  }
}
