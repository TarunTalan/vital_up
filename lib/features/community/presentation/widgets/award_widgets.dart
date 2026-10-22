import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/user_avatar.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _points = NumberFormat.decimalPattern();

/// A trophy or medal in its own colours.
class AwardIcon extends StatelessWidget {
  final String asset;
  final double size;

  const AwardIcon(this.asset, {super.key, this.size = AppDimens.iconXl});

  @override
  Widget build(BuildContext context) => GameIcon(
    asset,
    fallback: Icons.emoji_events_rounded,
    size: size,
    color: AppColors.rankGold,
  );
}

/// "Monthly trophy", "Gold medal"...
String awardPrizeName(AwardPeriod period, int place) => switch (period) {
  AwardPeriod.month => 'Monthly trophy',
  AwardPeriod.week => switch (place) {
    1 => 'Gold medal',
    2 => 'Silver medal',
    _ => 'Bronze medal',
  },
};

/// One winner: prize, avatar, name and points. [large] for the global
/// monthly champions, the most important awards.
class AwardWinnerRow extends StatelessWidget {
  final AwardWinner winner;
  final AwardPeriod period;
  final bool large;
  final VoidCallback? onTap;

  const AwardWinnerRow({
    super.key,
    required this.winner,
    required this.period,
    this.large = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = winner.displayName?.trim();
    final shown = name == null || name.isEmpty ? '@${winner.username}' : name;
    final iconSize = large ? AppDimens.iconXl : AppDimens.iconLg;
    return Semantics(
      label:
          '${awardPlaceLabel(winner.place)}, $shown, '
          '${_points.format(winner.points)} points',
      excludeSemantics: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.space6),
          child: Row(
            children: [
              SizedBox.square(
                dimension: AppDimens.iconXl,
                child: Center(
                  child: AwardIcon(
                    AwardIcons.forPlace(period, winner.place),
                    size: iconSize,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space10),
              UserAvatar(
                username: winner.username,
                url: winner.avatarUrl,
                size: AppDimens.avatarSmall,
              ),
              const SizedBox(width: AppDimens.space10),
              Expanded(
                child: Text(
                  winner.isMe ? '$shown (you)' : shown,
                  style:
                      (large
                              ? context.text.titleSmall
                              : context.text.bodyMedium)
                          ?.copyWith(
                            color: context.colors.onSurface,
                            fontWeight: winner.isMe ? FontWeight.w700 : null,
                          ),
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Text(
                '${_points.format(winner.points)} pts',
                style: context.text.bodySmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppDimens.space4),
                const AppChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "How awards work" button for card headers.
class AwardRulesButton extends StatelessWidget {
  const AwardRulesButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'How awards work',
    icon: Icon(Icons.info_outline_rounded, color: context.vColors.grayText),
    onPressed: () => showAwardRulesSheet(context),
  );
}

/// When the next winners are announced; ticks every minute.
class AwardCountdownLine extends StatefulWidget {
  final AwardPeriod period;

  const AwardCountdownLine({super.key, required this.period});

  @override
  State<AwardCountdownLine> createState() => _AwardCountdownLineState();
}

class _AwardCountdownLineState extends State<AwardCountdownLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = nextAwardCountdown(widget.period, now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: AppDimens.iconXs,
          color: context.vColors.grayText,
        ),
        const SizedBox(width: AppDimens.space6),
        Expanded(
          child: Text(
            awardCountdownMessage(next, now),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// "This week's medals in 4d 6h", "Last month's trophies in 14h. Late logs
/// still count."
String awardCountdownMessage(AwardCountdown next, DateTime now) {
  final left = next.remaining(now);
  final week = next.period == AwardPeriod.week;
  final prize = week ? 'medals' : 'trophies';
  final which = next.ended
      ? (week ? "Last week's" : "Last month's")
      : (week ? "This week's" : "This month's");
  if (left == Duration.zero) return '$which $prize are being announced';
  final when = '$which $prize in ${formatAwardCountdown(left)}';
  return next.ended ? '$when. Late logs still count.' : when;
}

/// Arena card for the latest winners: last week's medals and last month's
/// trophies for everyone and the caller's city (Week / Month when both
/// have winners; opens on the one announced last). Global first and
/// larger. Shows when the next ones are announced.
class ChampionsCard extends StatefulWidget {
  final List<CommunityWinners> champions;

  /// Opens a community's leaderboard (its top 3, each a tap from their
  /// profile).
  final void Function(Community community)? onOpenCommunity;

  const ChampionsCard({
    super.key,
    required this.champions,
    this.onOpenCommunity,
  });

  @override
  State<ChampionsCard> createState() => _ChampionsCardState();
}

class _ChampionsCardState extends State<ChampionsCard> {
  /// Chosen by the user; until then the latest announced.
  AwardPeriod? _picked;

  @override
  Widget build(BuildContext context) {
    final withWinners = [
      for (final c in widget.champions)
        if (c.winners.isNotEmpty) c,
    ];
    final periods = {for (final c in withWinners) c.period};
    final period =
        (_picked != null && periods.contains(_picked) ? _picked : null) ??
        latestChampionsPeriod(withWinners) ??
        AwardPeriod.month;
    final month = period == AwardPeriod.month;
    final groups = [
      for (final c in withWinners)
        if (c.period == period) c,
    ];
    final grey = context.vColors.grayText;
    final start = groups.firstOrNull?.periodStart;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // A crown: the rows below carry the medals and trophies.
              AppIconBadge(
                color: AppColors.rankGold,
                icon: GameIcon(
                  GamificationIcons.crown,
                  fallback: Icons.workspace_premium_rounded,
                  size: AppDimens.iconMd,
                  color: AppIconBadge.glyphColor(context, AppColors.rankGold),
                ),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Champions', style: context.text.titleSmall),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      start == null
                          ? 'Top 3 win medals each week, trophies each month'
                          : '${month ? 'Trophies' : 'Medals'} · '
                                '${awardPeriodLabel(period, start)}',
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              const AwardRulesButton(),
            ],
          ),
          if (periods.length > 1) ...[
            const SizedBox(height: AppDimens.space12),
            AppSegmentedControl<AwardPeriod>(
              values: const [AwardPeriod.week, AwardPeriod.month],
              selected: period,
              label: (p) => p == AwardPeriod.week ? 'Last week' : 'Last month',
              onChanged: (p) => setState(() => _picked = p),
            ),
          ],
          const SizedBox(height: AppDimens.space4),
          for (final g in groups)
            _ChampionRow(
              group: g,
              period: period,
              onTap: widget.onOpenCommunity == null
                  ? null
                  : () => widget.onOpenCommunity!(g.community),
            ),
          const SizedBox(height: AppDimens.space12),
          AwardCountdownLine(period: period),
        ],
      ),
    );
  }
}

/// One community in [ChampionsCard]: its winner ("1st @mike · 1,220
/// pts", "and 1 more" on a tie), your own place when you placed, and a
/// chevron to its leaderboard.
class _ChampionRow extends StatelessWidget {
  final CommunityWinners group;
  final AwardPeriod period;
  final VoidCallback? onTap;

  const _ChampionRow({required this.group, required this.period, this.onTap});

  @override
  Widget build(BuildContext context) {
    final winners = group.winners;
    final firsts = winners.where((w) => w.place == winners.first.place);
    final top = firsts.first;
    final me = winners.where((w) => w.isMe).firstOrNull;
    final grey = context.vColors.grayText;
    final who = top.isMe ? 'You' : '@${top.username}';
    final ties = firsts.length - 1;
    final line = [
      '${awardPlaceLabel(top.place)} $who${ties > 0 ? ' and $ties more' : ''}',
      '${_points.format(top.points)} pts',
      if (me != null && !firsts.contains(me))
        'You ${awardPlaceLabel(me.place)}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
        child: Row(
          children: [
            AwardIcon(
              AwardIcons.forPlace(period, top.place),
              size: AppDimens.iconXl,
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.community.type == CommunityType.global
                        ? 'Everyone on VitalUp'
                        : group.community.name,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    line,
                    style: context.text.bodySmall?.copyWith(color: grey),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppDimens.space8),
              const AppChevron(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Leaderboard card for the chosen period: when its winners are
/// announced, then the last finished period's winners, if any.
class LeaderboardAwardsCard extends StatelessWidget {
  final AwardPeriod period;
  final List<AwardWinner> winners;
  final void Function(AwardWinner winner)? onOpenPlayer;

  const LeaderboardAwardsCard({
    super.key,
    required this.period,
    this.winners = const [],
    this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final month = period == AwardPeriod.month;
    final start = winners.firstOrNull?.periodStart;
    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AwardIcon(
                month ? AwardIcons.trophy : AwardIcons.gold,
                size: AppDimens.iconXl,
              ),
              const SizedBox(width: AppDimens.space10),
              Expanded(
                child: Text(
                  month ? 'Monthly trophies' : 'Weekly medals',
                  style: context.text.titleSmall,
                ),
              ),
              const AwardRulesButton(),
            ],
          ),
          AwardCountdownLine(period: period),
          if (start != null) ...[
            const SizedBox(height: AppDimens.space12),
            Text(
              'Last winners · ${awardPeriodLabel(period, start)}',
              style: context.text.labelLarge?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.space4),
            for (final w in winners)
              AwardWinnerRow(
                winner: w,
                period: period,
                onTap: onOpenPlayer == null ? null : () => onOpenPlayer!(w),
              ),
          ],
        ],
      ),
    );
  }
}

/// The award rules, in plain words.
Future<void> showAwardRulesSheet(BuildContext context) =>
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => const AwardRulesSheet(),
    );

class AwardRulesSheet extends StatelessWidget {
  const AwardRulesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    Widget glyph(IconData icon) => AppIconBadge(
      icon: Icon(icon),
      color: context.colors.primary,
      size: AppDimens.iconXl,
    );
    final rules = <(Widget, String, String)>[
      (
        const AwardIcon(AwardIcons.gold, size: AppDimens.iconXl),
        'Weekly medals',
        'The top 3 in each community win gold, silver and bronze.',
      ),
      (
        const AwardIcon(AwardIcons.trophy, size: AppDimens.iconXl),
        'Monthly trophies',
        'The top 3 each month win trophies, the biggest honour.',
      ),
      (
        glyph(Icons.how_to_reg_rounded),
        'Who can win',
        'Anyone with points that period and "Show me on leaderboards" on. '
            'A community needs ${AwardRules.minPlayers} players; ties share '
            'a place.',
      ),
      (
        glyph(Icons.visibility_rounded),
        'Where they show',
        'In your Achievements and on your profile. Arena shows the latest '
            'champions, and you and your friends get a note when you win.',
      ),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space12,
          context.gutter,
          AppDimens.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How awards work', style: context.text.titleLarge),
            const SizedBox(height: AppDimens.space4),
            Text(
              'Recognition for the top players. Results wait a few days '
              'so late logs still count.',
              style: context.text.bodyMedium?.copyWith(color: grey),
            ),
            for (final (icon, title, body) in rules) ...[
              const SizedBox(height: AppDimens.space16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleSmall),
                        const SizedBox(height: AppDimens.space2),
                        Text(
                          body,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimens.space16),
            const AwardCountdownLine(period: AwardPeriod.week),
            const SizedBox(height: AppDimens.space6),
            const AwardCountdownLine(period: AwardPeriod.month),
          ],
        ),
      ),
    );
  }
}

/// A player's best award and their trophy / medal counts. With
/// [onSeeAll] (more than one award) the card opens the full list.
class AwardsSummaryCard extends StatelessWidget {
  final List<CommunityAward> awards;
  final VoidCallback? onSeeAll;

  const AwardsSummaryCard({super.key, required this.awards, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    final best = sortByPrestige(awards).first;
    final tally = AwardTally.of(awards);
    final grey = context.vColors.grayText;
    String label(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final counts = [
      if (tally.trophies > 0)
        (
          AwardIcons.trophy,
          tally.trophies,
          label(tally.trophies, 'trophy', 'trophies'),
        ),
      if (tally.gold > 0)
        (
          AwardIcons.gold,
          tally.gold,
          label(tally.gold, 'gold medal', 'gold medals'),
        ),
      if (tally.silver > 0)
        (
          AwardIcons.silver,
          tally.silver,
          label(tally.silver, 'silver medal', 'silver medals'),
        ),
      if (tally.bronze > 0)
        (
          AwardIcons.bronze,
          tally.bronze,
          label(tally.bronze, 'bronze medal', 'bronze medals'),
        ),
    ];

    final seeAll = awards.length > 1 ? onSeeAll : null;
    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      onTap: seeAll,
      showChevron: seeAll != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AwardIcon(best.asset, size: AppDimens.iconBadge),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(best.title, style: context.text.titleSmall),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      '${awardPrizeName(best.period, best.place)} · '
                      '${best.periodLabel}',
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (awards.length > 1) ...[
            const SizedBox(height: AppDimens.space10),
            Wrap(
              spacing: AppDimens.space16,
              runSpacing: AppDimens.space6,
              children: [
                for (final (asset, count, spoken) in counts)
                  Semantics(
                    label: spoken,
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AwardIcon(asset, size: AppDimens.iconLg),
                        const SizedBox(width: AppDimens.space4),
                        Text(
                          '$count',
                          style: context.text.labelLarge?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Achievements page: the caller's community awards as one card (best award and
/// counts) under an "Awards" header; with more than one it opens
/// [PlayerAwardsPage]. Nothing until they have one; [spacing] above it.
class MyCommunityAwards extends StatefulWidget {
  final double spacing;

  const MyCommunityAwards({super.key, this.spacing = AppDimens.sectionGap});

  @override
  State<MyCommunityAwards> createState() => _MyCommunityAwardsState();
}

class _MyCommunityAwardsState extends State<MyCommunityAwards> {
  late final Future<List<CommunityAward>> _awards = _loadAwards(null);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityAward>>(
      future: _awards,
      builder: (context, snap) {
        final awards = snap.data;
        if (awards == null || awards.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: widget.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                'Awards',
                count: awards.length,
                actionLabel: 'How it works',
                onAction: () => showAwardRulesSheet(context),
              ),
              AwardsSummaryCard(
                awards: awards,
                onSeeAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerAwardsPage(awards: awards),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Awards are optional everywhere: a failed load shows nothing.
Future<List<CommunityAward>> _loadAwards(String? userId) =>
    Future.sync(
      () => sl<CommunityRepository>().getPlayerAwards(userId),
    ).catchError((Object e) {
      debugPrint('Awards failed to load: $e');
      return const <CommunityAward>[];
    });

/// Every award of one player ([username]; the caller's own when null):
/// the summary card, then one section per week or month, newest first,
/// each with its awards in order of importance.
class PlayerAwardsPage extends StatelessWidget {
  final String? username;
  final List<CommunityAward> awards;

  const PlayerAwardsPage({super.key, this.username, required this.awards});

  @override
  Widget build(BuildContext context) {
    final name = username;
    return AppScaffold(
      header: AppPageHeader(
        title: name == null ? 'Your awards' : 'Awards',
        subtitle: name == null ? null : '@$name',
        action: AppHeaderAction(
          tooltip: 'How awards work',
          icon: const Icon(Icons.info_outline_rounded),
          onTap: () => showAwardRulesSheet(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AwardsSummaryCard(awards: awards),
          AwardsByPeriod(awards: awards),
        ],
      ),
    );
  }
}

/// [awards] in one section per period ("Week of 12 Oct (8)"),
/// newest first and a month before the weeks in it; rows show the place,
/// community, prize and points.
class AwardsByPeriod extends StatelessWidget {
  final List<CommunityAward> awards;

  const AwardsByPeriod({super.key, required this.awards});

  @override
  Widget build(BuildContext context) {
    final groups = <(AwardPeriod, DateTime), List<CommunityAward>>{};
    for (final a in sortByPrestige(awards)) {
      groups.putIfAbsent((a.period, a.periodStart), () => []).add(a);
    }
    final keys = groups.keys.toList()
      ..sort((x, y) {
        final byStart = y.$2.compareTo(x.$2);
        if (byStart != 0) return byStart;
        return x.$1 == AwardPeriod.month ? -1 : 1;
      });
    final grey = context.vColors.grayText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in keys) ...[
          const SizedBox(height: AppDimens.sectionGap),
          // The rows' icons tell medals from trophies.
          AppSectionHeader(
            awardPeriodLabel(key.$1, key.$2),
            count: groups[key]!.length,
          ),
          AppListGroup(
            children: [
              for (final a in groups[key]!)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space16,
                    vertical: AppDimens.space10,
                  ),
                  child: Row(
                    children: [
                      AwardIcon(a.asset, size: AppDimens.iconXl),
                      const SizedBox(width: AppDimens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: context.text.titleSmall),
                            const SizedBox(height: AppDimens.space2),
                            Text(
                              awardPrizeName(a.period, a.place),
                              style: context.text.bodySmall?.copyWith(
                                color: grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimens.space8),
                      Text(
                        '${_points.format(a.points)} pts',
                        style: context.text.bodySmall?.copyWith(color: grey),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
