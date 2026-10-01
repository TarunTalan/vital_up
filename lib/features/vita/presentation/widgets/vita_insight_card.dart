import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_avatar.dart';

/// Cyan "insight" card with Vita's avatar — Figma Frame 431 on the
/// analysis / diet plan / stress guide screens.
class VitaInsightCard extends StatelessWidget {
  final Widget child;

  const VitaInsightCard({super.key, required this.child});

  /// Plain body-16 message.
  VitaInsightCard.message(String text, {super.key})
      : child = _InsightText(text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: true,
      blur: true,
      padding: AppDimens.cardPaddingLarge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VitaAvatar.insight(),
          const SizedBox(width: AppDimens.space20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _InsightText extends StatelessWidget {
  final String text;

  const _InsightText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text.bodyLarge?.copyWith(
        color: context.colors.onSurface,
        letterSpacing: 0,
      ),
    );
  }
}
