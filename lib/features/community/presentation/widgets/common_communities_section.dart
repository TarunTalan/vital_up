import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/domain/entities/common_community_rank.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _points = NumberFormat.decimalPattern();

Color _rankBadgeColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// Displays a friend's rank in all communities shared with the caller,
/// along with head-to-head comparison standing.
class CommonCommunitiesSection extends StatefulWidget {
  final String friendUserId;
  final String? friendUsername;

  const CommonCommunitiesSection({
    super.key,
    required this.friendUserId,
    this.friendUsername,
  });

  @override
  State<CommonCommunitiesSection> createState() =>
      _CommonCommunitiesSectionState();
}

class _CommonCommunitiesSectionState extends State<CommonCommunitiesSection> {
  late final Future<List<CommonCommunityRank>> _ranksFuture;

  @override
  void initState() {
    super.initState();
    _ranksFuture = sl<CommunityRepository>().getCommonCommunityRanks(
      widget.friendUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;

    return FutureBuilder<List<CommonCommunityRank>>(
      future: _ranksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.space16),
            child: Center(child: VitalUpLoader()),
          );
        }

        final ranks = snapshot.data ?? const [];
        if (ranks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimens.sectionGap),
            AppSectionHeader(
              'Common Communities',
              count: ranks.length,
            ),
            for (final r in ranks) ...[
              AppCard(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space12,
                  vertical: AppDimens.space10,
                ),
                child: Row(
                  children: [
                    // Community icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusCard,
                        ),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: GameIcon(
                          communityIconAsset(r.community),
                          fallback: Icons.groups_rounded,
                          size: 22,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.space12),

                    // Community name and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.community.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            r.friendPoints > 0
                                ? '${_points.format(r.friendPoints)} pts'
                                : r.community.rankedOn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                context.text.bodySmall?.copyWith(color: grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.space8),

                    // Friend's rank and comparison
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (r.friendRank != null && r.friendRank! <= 3) ...[
                              GameIcon(
                                GamificationIcons.leaderboardRank(
                                  r.friendRank!,
                                )!,
                                fallback: Icons.emoji_events_rounded,
                                size: 18,
                                color: _rankBadgeColor(r.friendRank!),
                              ),
                              const SizedBox(width: 3.5),
                            ],
                            Text(
                              r.friendRank != null ? '#${r.friendRank}' : '–',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: r.friendRank != null &&
                                        r.friendRank! <= 3
                                    ? _rankBadgeColor(r.friendRank!)
                                    : context.colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: (r.myRank != null &&
                                    r.friendRank != null &&
                                    r.myRank! < r.friendRank!)
                                ? AppColors.scoreBonus.withValues(alpha: 0.14)
                                : context.vColors.grayText!
                                    .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusPill),
                          ),
                          child: Text(
                            'You: #${r.myRank ?? '–'}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: (r.myRank != null &&
                                      r.friendRank != null &&
                                      r.myRank! < r.friendRank!)
                                  ? AppColors.scoreBonus
                                  : grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],
          ],
        );
      },
    );
  }
}
