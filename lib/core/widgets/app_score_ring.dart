import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// Figma `color grades` ring: 150dp track with a rounded progress arc and
/// the score + label centred in the arc colour ("heading 1" / "body 16 med").
class AppScoreRing extends StatelessWidget {
  /// 0–100.
  final int score;
  final String label;
  final Color color;

  const AppScoreRing({
    super.key,
    required this.score,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100).toInt();
    final size = context.w(AppDimens.scoreMeterSize);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: clamped / 100,
              strokeWidth: AppDimens.scoreMeterStroke,
              color: color,
              backgroundColor: context.vColors.track,
              strokeCap: StrokeCap.round,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              AppDimens.scoreMeterStroke + AppDimens.space8,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$clamped',
                    style: context.text.headlineLarge?.copyWith(color: color),
                  ),
                  Text(
                    label,
                    style: context.text.titleSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
