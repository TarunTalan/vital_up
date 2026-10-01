import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Ramp colour for stress level 1 (very calm) – 5 (very stressed).
Color stressColor(num level) =>
    AppColors.stressLevels[(level.round() - 1).clamp(0, 4)];

/// Emoji mood face that pops with an elastic bounce when selected.
class AnimatedMoodFace extends StatefulWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const AnimatedMoodFace({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<AnimatedMoodFace> createState() => _AnimatedMoodFaceState();
}

class _AnimatedMoodFaceState extends State<AnimatedMoodFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppDurations.bounce,
  );

  @override
  void didUpdateWidget(AnimatedMoodFace old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.selected ? AppDimens.moodFaceSelectedScale : 1.0;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, child) {
            // A quick hop on select, settling with an elastic overshoot.
            final t = Curves.elasticOut.transform(_pop.value);
            final hop = math.sin(_pop.value * math.pi) * AppDimens.space8;
            return Transform.translate(
              offset: Offset(0, -hop),
              child: Transform.scale(
                scale: _pop.isAnimating ? 1 + (scale - 1) * t : scale,
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppDurations.medium,
            width: AppDimens.moodFaceBox,
            height: AppDimens.moodFaceBox,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.selected
                  ? widget.color.withValues(alpha: 0.25)
                  : context.vColors.glassFill,
              border: Border.all(
                color: widget.selected
                    ? widget.color
                    : context.vColors.glassBorder!,
                width: widget.selected
                    ? AppDimens.borderThick
                    : AppDimens.borderThin,
              ),
            ),
            child: AnimatedOpacity(
              duration: AppDurations.medium,
              opacity: widget.selected ? 1 : 0.85,
              child: Text(
                widget.emoji,
                style: TextStyle(fontSize: AppDimens.moodFaceSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-shot confetti burst; plays whenever [trigger] changes.
class ConfettiBurst extends StatefulWidget {
  final int trigger;
  final Color color;

  const ConfettiBurst({super.key, required this.trigger, required this.color});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.confetti,
  );
  List<_Particle> _particles = const [];

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) {
      final random = math.Random(widget.trigger);
      final palette = [
        widget.color,
        AppColors.primary,
        AppColors.streak,
        ...AppColors.stressLevels.take(3),
      ];
      _particles = [
        for (var i = 0; i < 18; i++)
          _Particle(
            angle: -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 1.4,
            speed: 0.55 + random.nextDouble() * 0.45,
            spin: random.nextDouble() * math.pi * 4,
            color: palette[random.nextInt(palette.length)],
            round: random.nextBool(),
          ),
      ];
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.isAnimating
            ? CustomPaint(
                painter: _ConfettiPainter(_particles, _controller.value),
                size: Size.infinite,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double spin;
  final Color color;
  final bool round;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.color,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(t);
    const spread = AppDimens.confettiSpread;
    const p = AppDimens.confettiParticle;
    for (final particle in particles) {
      final distance = spread * particle.speed * eased;
      // Gravity pulls pieces down as the burst fades.
      final pos = origin +
          Offset(
            math.cos(particle.angle) * distance,
            math.sin(particle.angle) * distance + spread * 0.6 * t * t,
          );
      final paint = Paint()
        ..color = particle.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(particle.spin * t);
      if (particle.round) {
        canvas.drawCircle(Offset.zero, p / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p, height: p / 2),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
