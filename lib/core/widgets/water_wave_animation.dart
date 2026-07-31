import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaterWaveAnimation extends StatefulWidget {
  final double fillPercentage;
  final Color waveColor;
  final Color backgroundColor;

  const WaterWaveAnimation({
    super.key,
    required this.fillPercentage,
    required this.waveColor,
    required this.backgroundColor,
  });

  @override
  State<WaterWaveAnimation> createState() => _WaterWaveAnimationState();
}

class _WaterWaveAnimationState extends State<WaterWaveAnimation>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _splashController;
  
  double _oldPercentage = 0.0;
  bool _showSplash = false;

  @override
  void initState() {
    super.initState();
    _oldPercentage = widget.fillPercentage;
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _waveController.repeat();
  }

  @override
  void didUpdateWidget(covariant WaterWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fillPercentage != widget.fillPercentage) {
      if (widget.fillPercentage > oldWidget.fillPercentage) {
        // Trigger splash on add
        _triggerSplash();
      }
      _oldPercentage = widget.fillPercentage;
    }
  }
  
  void _triggerSplash() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    
    setState(() {
      _showSplash = true;
    });
    _splashController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _waveController.stop();
    } else if (!_waveController.isAnimating) {
      _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final clampedPercentage = widget.fillPercentage.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: widget.backgroundColor,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Smoothly animate the height based on fill percentage
            AnimatedContainer(
              duration: disableAnimations
                  ? const Duration(milliseconds: 0)
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              height: clampedPercentage * 200, // Assuming a fixed height or max height. We'll use a LayoutBuilder if dynamic is needed.
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WavePainter(
                      waveAnimationValue: disableAnimations ? 0.0 : _waveController.value,
                      waveColor: widget.waveColor,
                    ),
                    child: Container(),
                  );
                },
              ),
            ),
            
            // Splash effect overlay
            if (_showSplash)
              Positioned(
                bottom: (clampedPercentage * 200) - 15,
                child: AnimatedBuilder(
                  animation: _splashController,
                  builder: (context, child) {
                    final scale = 1.0 + (_splashController.value * 0.5);
                    final opacity = 1.0 - _splashController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 40,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.waveColor.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double waveAnimationValue;
  final Color waveColor;

  _WavePainter({
    required this.waveAnimationValue,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height == 0 || size.width == 0) return;

    final paintFront = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final paintBack = Paint()
      ..color = waveColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final pathFront = Path();
    final pathBack = Path();

    // Wave parameters
    final double waveHeight = math.min(10.0, size.height * 0.1); // Wave amplitude
    final double waveWidth = size.width;

    // We draw two waves offset by phase and slightly in amplitude
    pathFront.moveTo(0, waveHeight);
    pathBack.moveTo(0, waveHeight);

    for (double i = 0.0; i <= size.width; i++) {
      // Front wave
      final double yFront = waveHeight *
              math.sin((i / waveWidth * 2 * math.pi) +
                  (waveAnimationValue * 2 * math.pi)) +
          waveHeight;
      
      // Back wave (moving slightly faster, opposite phase)
      final double yBack = (waveHeight * 0.8) *
              math.sin((i / waveWidth * 2 * math.pi) +
                  (waveAnimationValue * 3 * math.pi) + math.pi) +
          waveHeight;

      pathFront.lineTo(i, yFront);
      pathBack.lineTo(i, yBack);
    }

    pathFront.lineTo(size.width, size.height);
    pathFront.lineTo(0, size.height);
    pathFront.close();

    pathBack.lineTo(size.width, size.height);
    pathBack.lineTo(0, size.height);
    pathBack.close();

    canvas.drawPath(pathBack, paintBack);
    canvas.drawPath(pathFront, paintFront);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.waveAnimationValue != waveAnimationValue ||
           oldDelegate.waveColor != waveColor;
  }
}
