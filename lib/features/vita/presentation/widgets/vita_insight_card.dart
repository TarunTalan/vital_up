import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_avatar.dart';

/// Something Vita says on its own pages: highlighted card with Vita's
/// avatar beside the text.
class VitaInsightCard extends StatelessWidget {
  final Widget child;

  const VitaInsightCard({super.key, required this.child});

  /// A plain message in body text.
  VitaInsightCard.message(String text, {super.key})
    : child = _InsightText(text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VitaAvatar(),
          const SizedBox(width: AppDimens.space12),
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
      style: context.text.bodyLarge?.copyWith(color: context.colors.onSurface),
    );
  }
}
