import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

final _numberFormat = NumberFormat.decimalPattern();

/// A full "Gamer Dossier" player inspect sheet that opens when tapping on a friend.
/// Displays their level badge, tier, stats, head-to-head comparison, and actions.
class PlayerInspectSheet extends StatelessWidget {
  final Friend friend;
  final VoidCallback? onRemove;

  const PlayerInspectSheet({
    super.key,
    required this.friend,
    this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required Friend friend,
    VoidCallback? onRemove,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => BlocProvider<GamificationCubit>.value(
        value: sl<GamificationCubit>()..load(),
        child: PlayerInspectSheet(
          friend: friend,
          onRemove: onRemove,
        ),
      ),
    );
  }

  void _cheerFriend(BuildContext context) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 You sent a High-Five cheer to @${friend.username}!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final tier = LevelTierConfig.forLevel(friend.level);

    return BlocBuilder<GamificationCubit, GamificationState>(
      builder: (context, myState) {
        final myStats = myState.stats ?? PlayerStats.empty;
        final myLevel = myStats.level.level;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.gutter,
              AppDimens.space12,
              AppDimens.gutter,
              AppDimens.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: AppDimens.sheetHandleWidth,
                    height: AppDimens.sheetHandleHeight,
                    margin: const EdgeInsets.only(bottom: AppDimens.space16),
                    decoration: BoxDecoration(
                      color: v.glassBorder,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    ),
                  ),
                ),

                // Player Hero Banner with Level Badge & Avatar
                Container(
                  padding: AppDimens.cardPaddingCompact,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceDarkElevated,
                        AppColors.surfaceDark,
                        tier.gradientColors.first.withValues(alpha: 0.15),
                      ],
                    ),
                    border: Border.all(
                      color: tier.borderColor.withValues(alpha: 0.4),
                      width: AppDimens.borderThin + 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tier.glowColor.withValues(alpha: 0.2),
                        blurRadius: AppDimens.space16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Large Level Badge
                      LevelBadgeWidget(
                        level: friend.level,
                        size: 64,
                        showGlow: true,
                      ),
                      const SizedBox(width: AppDimens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  username: friend.username,
                                  url: friend.avatarUrl,
                                  size: AppDimens.avatarSmall,
                                  ringColor: tier.borderColor,
                                ),
                                const SizedBox(width: AppDimens.space8),
                                Flexible(
                                  child: Text(
                                    '@${friend.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleMedium?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimens.space6),
                            Text(
                              tier.tag,
                              style: context.text.labelSmall?.copyWith(
                                color: tier.borderColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'LEVEL ${friend.level} • ${tier.tierName}',
                              style: context.text.bodySmall?.copyWith(
                                color: v.grayText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.space16),

                // Head-to-Head Comparison Card (You vs Friend)
                Container(
                  padding: AppDimens.cardPaddingCompact,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    border: Border.all(
                      color: v.glassBorder!,
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YOU',
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.compare_arrows_rounded,
                                size: 14,
                                color: AppColors.rankGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'HEAD-TO-HEAD',
                                style: context.text.labelSmall?.copyWith(
                                  color: AppColors.rankGold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            friend.username.toUpperCase(),
                            style: context.text.labelSmall?.copyWith(
                              color: tier.borderColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.space12),
                      _buildComparisonRow(
                        label: 'Player Level',
                        myVal: 'Lv. $myLevel',
                        friendVal: 'Lv. ${friend.level}',
                        highlightMy: myLevel >= friend.level,
                      ),
                      const SizedBox(height: AppDimens.space8),
                      _buildComparisonRow(
                        label: 'Active Streak',
                        myVal: '${myStats.streak} Days',
                        friendVal: 'Active',
                        highlightMy: myStats.streak > 0,
                      ),
                      const SizedBox(height: AppDimens.space8),
                      _buildComparisonRow(
                        label: 'Total XP',
                        myVal: '${_numberFormat.format(myStats.totalPoints)} XP',
                        friendVal: 'Level ${friend.level}',
                        highlightMy: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.space16),

                // Primary Action: 1v1 Challenge Button
                AppPrimaryButton(
                  label: 'Challenge to 1v1 Duel',
                  leadingIcon: const Icon(Icons.sports_martial_arts_rounded),
                  onTap: () {
                    Navigator.of(context).pop();
                    QuickChallengeSheet.show(context, friend: friend);
                  },
                ),

                const SizedBox(height: AppDimens.space8),

                // Secondary Actions: Cheer / Nudge & Remove
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Send High-Five',
                        leadingIcon: const Icon(
                          Icons.celebration_rounded,
                          size: AppDimens.iconSm,
                        ),
                        onTap: () => _cheerFriend(context),
                      ),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: AppDimens.space8),
                      IconButton(
                        tooltip: 'Remove Friend',
                        icon: Icon(
                          Icons.person_remove_outlined,
                          color: context.colors.error,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onRemove!();
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String myVal,
    required String friendVal,
    required bool highlightMy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          myVal,
          style: TextStyle(
            color: highlightMy ? AppColors.white : AppColors.greyText,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.greyText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          friendVal,
          style: TextStyle(
            color: !highlightMy ? AppColors.white : AppColors.greyText,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
