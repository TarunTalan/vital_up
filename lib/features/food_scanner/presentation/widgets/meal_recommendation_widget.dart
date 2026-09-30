import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_recommendation.dart';

class MealRecommendationWidget extends StatelessWidget {
  final MealRecommendation recommendation;

  const MealRecommendationWidget({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                color: v.success,
                icon: const Icon(Icons.lightbulb_outline_rounded),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text('Recommendation', style: context.text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Text(recommendation.message, style: context.text.bodyMedium),
          if (recommendation.reasonTags.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space12),
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: recommendation.reasonTags
                  .map((tag) => Chip(
                        label: Text(
                          _formatTag(tag),
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                        backgroundColor: v.successTint,
                        side: BorderSide(
                          color: v.success!.withValues(alpha: 0.27),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTag(String tag) {
    return tag
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
