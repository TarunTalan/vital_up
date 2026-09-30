import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_dimens.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// Figma "loader animation" (724:5289): four 50dp wellness icons on a
/// 60dp grid (10dp gaps) that rotate a quarter turn at a time.
class VitalUpLoader extends StatefulWidget {
  final double size;
  final double iconSize;

  const VitalUpLoader({
    super.key,
    this.size = AppDimens.loaderSize,
    this.iconSize = AppDimens.loaderIcon,
  });

  @override
  State<VitalUpLoader> createState() => _VitalUpLoaderState();
}

class _VitalUpLoaderState extends State<VitalUpLoader>
    with SingleTickerProviderStateMixin {
  static const _stepDurationMs = 1200;
  static const _pauseDurationMs = 450;
  static const _cycleDuration = Duration(
    milliseconds: _stepDurationMs + _pauseDurationMs,
  );
  static const _rotationPhaseEnd =
      _stepDurationMs / (_stepDurationMs + _pauseDurationMs);
  static const _bottomLeftIconByQuarterTurn = [2, 3, 1, 0];
  static const _topRightIconByQuarterTurn = [1, 0, 2, 3];

  late final AnimationController _controller;
  int _completedQuarterTurns = 0;
  bool _hasCompletedPause = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        _completedQuarterTurns = (_completedQuarterTurns + 1) % 4;
        _hasCompletedPause = true;
        _controller.forward(from: 0);
      })
      ..forward();
  }

  double _ease(double value) {
    return Curves.easeInOut.transform(value.clamp(0.0, 1.0));
  }

  int _bottomLeftIconIndex(int quarterTurns) {
    return _bottomLeftIconByQuarterTurn[quarterTurns % 4];
  }

  int _topRightIconIndex(int quarterTurns) {
    return _topRightIconByQuarterTurn[quarterTurns % 4];
  }

  List<double> _pauseVisualTurns({
    required int quarterTurns,
    required double progress,
  }) {
    final bottomLeftIconIndex = _bottomLeftIconIndex(quarterTurns);
    final topRightIconIndex = _topRightIconIndex(quarterTurns);

    return List.generate(4, (index) {
      if (index == bottomLeftIconIndex) return 0.0;
      if (index == topRightIconIndex) return progress * 0.5;

      return progress * 0.25;
    });
  }

  ({double groupTurns, List<double> iconTurns, double offsetScale})
  _rotationState() {
    final progress = _controller.value;

    if (progress <= _rotationPhaseEnd) {
      final rotationProgress = _ease(progress / _rotationPhaseEnd);
      final groupTurns = (_completedQuarterTurns + rotationProgress) * 0.25;
      final offsetScale = 1.0 - (0.18 * math.sin(math.pi * rotationProgress));
      final startingVisualTurns = _hasCompletedPause
          ? _pauseVisualTurns(
              quarterTurns: _completedQuarterTurns,
              progress: 1.0,
            )
          : List.filled(4, 0.0);
      final previousTopRightIconIndex = _topRightIconIndex(
        _completedQuarterTurns,
      );
      final iconTurns = List.generate(4, (index) {
        final startingTurns = startingVisualTurns[index];
        final visualTurns =
            _hasCompletedPause && index == previousTopRightIconIndex
            ? startingTurns + ((1.0 - startingTurns) * rotationProgress)
            : startingTurns * (1.0 - rotationProgress);

        return visualTurns - groupTurns;
      });

      return (
        groupTurns: groupTurns,
        iconTurns: iconTurns,
        offsetScale: offsetScale,
      );
    }

    final pauseProgress = _ease(
      (progress - _rotationPhaseEnd) / (1.0 - _rotationPhaseEnd),
    );
    final groupTurns = (_completedQuarterTurns + 1) * 0.25;
    final visualTurns = _pauseVisualTurns(
      quarterTurns: _completedQuarterTurns + 1,
      progress: pauseProgress,
    );

    return (
      groupTurns: groupTurns,
      iconTurns: visualTurns.map((turns) => turns - groupTurns).toList(),
      offsetScale: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Apply a scale factor to make it smaller, and use context.w() to make it responsive
    final responsiveSize = context.w(widget.size * 0.6);
    final responsiveIconSize = context.w(widget.iconSize * 0.6);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final rotationState = _rotationState();
          // Increase multiplier from 0.6 to 0.85 to add more space between the icons
          final d = responsiveIconSize * 0.85;

          return RotationTransition(
            turns: AlwaysStoppedAnimation(rotationState.groupTurns),
            child: SizedBox.square(
              dimension: responsiveSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _LoaderIcon(
                    assetPath: 'assets/icons/smile.svg',
                    size: responsiveIconSize,
                    offset: Offset(-d, -d),
                    offsetScale: rotationState.offsetScale,
                    turns: rotationState.iconTurns[0],
                  ),
                  _LoaderIcon(
                    assetPath: 'assets/icons/Apple.svg',
                    size: responsiveIconSize,
                    offset: Offset(d, -d),
                    offsetScale: rotationState.offsetScale,
                    turns: rotationState.iconTurns[1],
                  ),
                  _LoaderIcon(
                    assetPath: 'assets/icons/flower.svg',
                    size: responsiveIconSize,
                    offset: Offset(-d, d),
                    offsetScale: rotationState.offsetScale,
                    turns: rotationState.iconTurns[2],
                  ),
                  _LoaderIcon(
                    assetPath: 'assets/icons/drop.svg',
                    size: responsiveIconSize,
                    offset: Offset(d, d),
                    offsetScale: rotationState.offsetScale,
                    turns: rotationState.iconTurns[3],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoaderIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Offset offset;
  final double offsetScale;
  final double turns;

  const _LoaderIcon({
    required this.assetPath,
    required this.size,
    required this.offset,
    required this.offsetScale,
    this.turns = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offset.dx * offsetScale, offset.dy * offsetScale),
      child: RotationTransition(
        turns: AlwaysStoppedAnimation(turns),
        child: SvgPicture.asset(assetPath, width: size, height: size),
      ),
    );
  }
}
