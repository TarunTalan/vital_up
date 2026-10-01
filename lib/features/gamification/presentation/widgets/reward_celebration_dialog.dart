import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/gamification/domain/entities/award_result.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

/// Shows a level-up / new-badge celebration for [award].
Future<void> showRewardCelebration(BuildContext context, AwardResult award) =>
    showSmoothDialog(
      context: context,
      builder: (_) => RewardCelebrationDialog(award: award),
    );

class RewardCelebrationDialog extends StatelessWidget {
  final AwardResult award;

  const RewardCelebrationDialog({super.key, required this.award});

  @override
  Widget build(BuildContext context) {
    final badge = award.newBadges.firstOrNull;
    final title = award.levelUp
        ? 'Level ${award.level}!'
        : award.newBadges.length > 1
        ? '${award.newBadges.length} new badges!'
        : 'Badge unlocked!';
    final subtitle = award.levelUp
        ? "You've levelled up. Keep it going!"
        : badge?.description ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
      ),
      child: Padding(
        padding: AppDimens.cardPaddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimens.celebrationBadge,
              height: AppDimens.celebrationBadge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.rankGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: award.levelUp || badge == null
                  ? Text(
                      '${award.level}',
                      style: context.text.headlineLarge?.copyWith(
                        color: AppColors.rankGold,
                      ),
                    )
                  : GameIcon(
                      GamificationIcons.badge(badge.iconKey),
                      fallback: Icons.military_tech_rounded,
                      size: AppDimens.iconXxl,
                      color: AppColors.rankGold,
                    ),
            ),
            const SizedBox(height: AppDimens.space16),
            Text(
              title,
              style: context.text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            if (award.newBadges.isNotEmpty) ...[
              const SizedBox(height: AppDimens.space12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppDimens.space8,
                runSpacing: AppDimens.space8,
                children: [
                  for (final b in award.newBadges)
                    Chip(
                      avatar: GameIcon(
                        GamificationIcons.badge(b.iconKey),
                        fallback: Icons.military_tech_rounded,
                        size: AppDimens.iconSm,
                        color: AppColors.rankGold,
                      ),
                      label: Text(b.name),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Awesome',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
