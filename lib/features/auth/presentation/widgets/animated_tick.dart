import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedTick extends StatefulWidget {
  final double totalSize;
  final double tickSize;
  final bool play;
  final VoidCallback? onFinished;

  const AnimatedTick({
    super.key,
    this.totalSize = 115.0,
    this.tickSize = 55.0,
    this.play = true,
    this.onFinished,
  });

  @override
  State<AnimatedTick> createState() => _AnimatedTickState();
}

class _AnimatedTickState extends State<AnimatedTick> with TickerProviderStateMixin {
  late AnimationController _borderController;
  late AnimationController _popController;

  late Animation<double> _borderProgress;
  late Animation<double> _scaleProgress;
  late Animation<double> _rotationProgress;

  @override
  void initState() {
    super.initState();

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _borderProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _borderController, curve: Curves.easeInOut),
    );

    // Spring/bounce effect for checkmark scale
    _scaleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.elasticOut),
    );

    _rotationProgress = Tween<double>(begin: -15.0 * (math.pi / 180.0), end: 0.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOut),
    );

    if (widget.play) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play != oldWidget.play) {
      if (widget.play) {
        _startAnimation();
      } else {
        _resetAnimation();
      }
    }
  }

  void _startAnimation() {
    _borderController.forward().then((_) {
      _popController.forward().then((_) {
        if (widget.onFinished != null) {
          widget.onFinished!();
        }
      });
    });
  }

  void _resetAnimation() {
    _borderController.reset();
    _popController.reset();
  }

  @override
  void dispose() {
    _borderController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.totalSize,
      height: widget.totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _borderProgress,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.totalSize, widget.totalSize),
                painter: _TickBorderPainter(
                  progress: _borderProgress.value,
                  bgColor: const Color(0xFFC2E6B6),
                  borderColor: const Color(0xFF5C9F47),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _popController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleProgress.value,
                child: Transform.rotate(
                  angle: _rotationProgress.value,
                  child: Icon(
                    Icons.check,
                    color: const Color(0xFF5C9F47),
                    size: widget.tickSize,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TickBorderPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color borderColor;

  _TickBorderPainter({
    required this.progress,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide / 2;
    final double strokeWidth = size.shortestSide * 0.08;

    // Draw background circle
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius - strokeWidth / 2, bgPaint);

    // Draw animated border arc
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius - strokeWidth / 2,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TickBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.borderColor != borderColor;
  }
}
