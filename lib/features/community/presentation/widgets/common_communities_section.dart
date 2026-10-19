import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/features/community/domain/entities/common_community_rank.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _rank = NumberFormat.decimalPattern();

Color _medalColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// Who is ahead between two all-time ranks; null when neither is ranked.
/// Positive: the caller is ahead.
int? compareRanks(int? mine, int? theirs) {
  if (mine == null && theirs == null) return null;
  if (mine == null) return -1;
  if (theirs == null) return 1;
  return theirs.compareTo(mine);
}

/// Compare page section: each community the caller shares with a friend,
/// with both all-time ranks side by side and who is ahead. Shows nothing
/// until there is something to compare.
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
  late final Future<List<CommonCommunityRank>> _ranks =
      sl<CommunityRepository>().getCommonCommunityRanks(widget.friendUserId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommonCommunityRank>>(
      future: _ranks,
      builder: (context, snapshot) {
        final ranks = snapshot.data ?? const <CommonCommunityRank>[];
        // Nothing while loading or empty: the section only adds to the page.
        if (ranks.isEmpty) return const SizedBox.shrink();
        final them = widget.friendUsername == null
            ? 'Them'
            : '@${widget.friendUsername}';
        return Padding(
          padding: const EdgeInsets.only(top: AppDimens.sectionGap),
          child: AppListGroup(
            title: 'Communities · all time',
            children: [
              for (final r in ranks) _CommunityRankRow(rank: r, them: them),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityRankRow extends StatelessWidget {
  final CommonCommunityRank rank;
  final String them;

  const _CommunityRankRow({required this.rank, required this.them});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final lead = compareRanks(rank.myRank, rank.friendRank);
    final verdict = switch (lead) {
      null => 'Neither of you is ranked yet',
      0 => "You're tied",
      > 0 => "You're ahead",
      _ => '$them is ahead',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space10,
      ),
      child: Row(
        children: [
          AppIconBadge(
            color: context.colors.primary,
            icon: GameIcon(
              communityIconAsset(rank.community),
              fallback: communityFallbackIcon(rank.community),
              size: AppDimens.iconMd,
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank.community.name,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  verdict,
                  style: context.text.bodySmall?.copyWith(
                    color: lead != null && lead > 0
                        ? context.vColors.accentText
                        : grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          _RankCell(label: 'You', rank: rank.myRank),
          const SizedBox(width: AppDimens.space12),
          _RankCell(label: 'Them', rank: rank.friendRank),
        ],
      ),
    );
  }
}

/// A rank over its owner: medal for the top three, "#12", or "–".
class _RankCell extends StatelessWidget {
  final String label;
  final int? rank;

  const _RankCell({required this.label, required this.rank});

  @override
  Widget build(BuildContext context) {
    final r = rank;
    return Semantics(
      label: '$label: ${r == null ? 'not ranked' : 'rank $r'}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppDimens.rankColumnWidth),
        child: Column(
          children: [
            SizedBox(
              height: AppDimens.iconLg,
              child: r != null && r <= 3
                  ? GameIcon(
                      GamificationIcons.leaderboardRank(r)!,
                      fallback: Icons.military_tech_rounded,
                      size: AppDimens.iconLg,
                      color: _medalColor(r),
                    )
                  : Center(
                      child: Text(
                        r == null ? '–' : '#${_rank.format(r)}',
                        style: context.text.titleSmall?.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
            ),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
