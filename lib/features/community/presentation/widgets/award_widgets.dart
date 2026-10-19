import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
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

/// Arena card for last month's winners: Global first and largest, then
/// the caller's city. Before any winners it explains the trophies. Always
/// shows when the next ones are announced.
class MonthlyChampionsCard extends StatelessWidget {
  final List<CommunityWinners> champions;
  final void Function(AwardWinner winner)? onOpenPlayer;

  const MonthlyChampionsCard({
    super.key,
    required this.champions,
    this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final c in champions)
        if (c.winners.isNotEmpty) c,
    ];
    final grey = context.vColors.grayText;
    final start = groups.firstOrNull?.periodStart;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AwardIcon(AwardIcons.trophy, size: AppDimens.iconBadge),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly champions', style: context.text.titleMedium),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      start == null
                          ? 'Top 3 each month win a trophy'
                          : awardPeriodLabel(AwardPeriod.month, start),
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              const AwardRulesButton(),
            ],
          ),
          for (final g in groups) ...[
            const SizedBox(height: AppDimens.space12),
            Text(
              g.community.type == CommunityType.global
                  ? 'Everyone on VitalUp'
                  : g.community.name,
              style: context.text.labelLarge?.copyWith(color: grey),
            ),
            const SizedBox(height: AppDimens.space4),
            for (final w in g.winners)
              AwardWinnerRow(
                winner: w,
                period: AwardPeriod.month,
                large: g.community.type == CommunityType.global,
                onTap: onOpenPlayer == null || w.isMe
                    ? null
                    : () => onOpenPlayer!(w),
              ),
          ],
          const SizedBox(height: AppDimens.space12),
          const AwardCountdownLine(period: AwardPeriod.month),
        ],
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
                onTap: onOpenPlayer == null || w.isMe
                    ? null
                    : () => onOpenPlayer!(w),
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
    const rules = [
      (
        AwardIcons.trophy,
        'Monthly trophies',
        'The top 3 of each leaderboard for the month win a trophy. '
            'Global champions rank highest, then your city, then the '
            'communities you joined.',
      ),
      (
        AwardIcons.gold,
        'Weekly medals',
        'The top 3 of each leaderboard from Monday to Sunday win gold, '
            'silver and bronze medals.',
      ),
      (
        AwardIcons.starTrophy,
        'When winners are announced',
        'Results are final ${AwardRules.lateDays} days after the period '
            'ends, so logs you sync late still count: Thursday for the '
            'week, the 4th for the month (just after midnight India time).',
      ),
      (
        AwardIcons.silver,
        'Who can win',
        'You need points that period and "Show me on leaderboards" turned '
            'on. A leaderboard needs at least ${AwardRules.minPlayers} '
            'players with points. Tied players share the place.',
      ),
      (
        AwardIcons.bronze,
        'Where they show',
        "You'll get a notification. Your awards appear with your badges "
            'and on your profile for other players.',
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
              'Awards are extra. Points still come from logging your habits.',
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            for (final (asset, title, body) in rules) ...[
              const SizedBox(height: AppDimens.space16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AwardIcon(asset, size: AppDimens.iconXl),
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

/// A player's best award and their trophy / medal counts.
class AwardsSummaryCard extends StatelessWidget {
  final List<CommunityAward> awards;

  const AwardsSummaryCard({super.key, required this.awards});

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

    return AppCard(
      padding: AppDimens.cardPaddingCompact,
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

/// Loads [userId]'s awards (the caller when null) and shows
/// [AwardsSummaryCard] with [spacing] above it; nothing when they have
/// none or loading fails.
class PlayerAwardsSummary extends StatefulWidget {
  final String? userId;
  final double spacing;

  const PlayerAwardsSummary({
    super.key,
    this.userId,
    this.spacing = AppDimens.space12,
  });

  @override
  State<PlayerAwardsSummary> createState() => _PlayerAwardsSummaryState();
}

class _PlayerAwardsSummaryState extends State<PlayerAwardsSummary> {
  late final Future<List<CommunityAward>> _awards = _loadAwards(widget.userId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityAward>>(
      future: _awards,
      builder: (context, snap) {
        final awards = snap.data;
        if (awards == null || awards.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: widget.spacing),
          child: AwardsSummaryCard(awards: awards),
        );
      },
    );
  }
}

/// Loads the caller's awards for the Badges page; nothing until they have
/// one, with [spacing] below when shown.
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
          padding: EdgeInsets.only(bottom: widget.spacing),
          child: CommunityAwardsSection(awards: awards),
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

/// Badges page section: every award, most important first.
class CommunityAwardsSection extends StatelessWidget {
  final List<CommunityAward> awards;

  const CommunityAwardsSection({super.key, required this.awards});

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    final grey = context.vColors.grayText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          'Community awards',
          count: awards.length,
          actionLabel: 'How it works',
          onAction: () => showAwardRulesSheet(context),
        ),
        AppListGroup(
          children: [
            for (final a in sortByPrestige(awards))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space16,
                  vertical: AppDimens.space10,
                ),
                child: Row(
                  children: [
                    AwardIcon(a.asset, size: AppDimens.iconBadge),
                    const SizedBox(width: AppDimens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: context.text.titleSmall),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            '${awardPrizeName(a.period, a.place)} · '
                            '${a.periodLabel}',
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
    );
  }
}
