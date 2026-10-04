import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';

/// High-visibility gaming invite card that encourages inviting friends
/// for gamification bonus XP (+200 XP referral bonus).
class InviteShareCard extends StatelessWidget {
  final String? myUsername;

  const InviteShareCard({
    super.key,
    this.myUsername,
  });

  void _shareInvite(BuildContext context) {
    final name = myUsername ?? 'vitalup';
    final shareText = 'Join me on VitalUp to track fitness, complete 1v1 challenges, and level up! Add me: @$name';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Invite message copied to clipboard! Share it with your friends.'),
      ),
    );
  }

  void _copyUsername(BuildContext context) {
    if (myUsername == null) return;
    Clipboard.setData(ClipboardData(text: '@$myUsername'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied @$myUsername — share it so friends can add you!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimens.space16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        color: v.glassFill,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.rankGold.withValues(alpha: 0.12),
            AppColors.surfaceDark,
            context.colors.primary.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: AppColors.rankGold.withValues(alpha: 0.4),
          width: AppDimens.borderThin + 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rankGold.withValues(alpha: 0.15),
            blurRadius: AppDimens.space16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: AppDimens.cardPaddingCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Gift Icon & XP Tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimens.space8),
                  decoration: BoxDecoration(
                    color: AppColors.rankGold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.rankGold.withValues(alpha: 0.6),
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    size: AppDimens.iconMd,
                    color: AppColors.rankGold,
                  ),
                ),
                const SizedBox(width: AppDimens.space10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'INVITE FRIENDS',
                              style: context.text.titleSmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.space6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.space6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.rankGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                            ),
                            child: Text(
                              '+200 XP',
                              style: context.text.labelSmall?.copyWith(
                                color: AppColors.rankGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Earn +200 bonus points when a friend joins!',
                        style: context.text.bodySmall?.copyWith(color: v.grayText),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.space12),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Share Invite',
                    leadingIcon: const Icon(
                      Icons.share_rounded,
                      size: AppDimens.iconSm,
                    ),
                    onTap: () => _shareInvite(context),
                  ),
                ),
                if (myUsername != null && myUsername!.isNotEmpty) ...[
                  const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: AppSecondaryButton(
                      label: '@$myUsername',
                      leadingIcon: const Icon(
                        Icons.copy_rounded,
                        size: AppDimens.iconSm,
                      ),
                      onTap: () => _copyUsername(context),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
