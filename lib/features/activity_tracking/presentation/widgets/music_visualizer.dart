import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Four animated equaliser bars shown while a track is playing.
class MusicVisualizer extends StatefulWidget {
  final Color color;
  final bool isPlaying;

  const MusicVisualizer({
    super.key,
    required this.color,
    this.isPlaying = true,
  });

  @override
  State<MusicVisualizer> createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<MusicVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<int> _durations = [900, 800, 1000, 700];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(MusicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = 0.3;
            if (widget.isPlaying) {
              final t = (_controller.value * 1000 / _durations[index]) % 1.0;
              value = 0.3 + 0.7 * (0.5 - (0.5 - t).abs()) * 2;
            }
            return Container(
              width: AppDimens.space2,
              height: AppDimens.iconXs * value,
              margin: const EdgeInsets.symmetric(
                horizontal: AppDimens.borderThin,
              ),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            );
          },
        );
      }),
    );
  }
}
