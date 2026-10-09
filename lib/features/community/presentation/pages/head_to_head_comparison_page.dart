import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

final _number = NumberFormat.decimalPattern();

/// One compared figure: its label and each side's value.
typedef _Stat = ({
  String label,
  int mine,
  int theirs,
  String Function(int) format,
});

/// You and a friend side by side: level, points, streaks, badges and
/// points per category, all from the server so both sides are measured
/// the same way.
class HeadToHeadComparisonPage extends StatefulWidget {
  final Friend friend;

  const HeadToHeadComparisonPage({super.key, required this.friend});

  @override
  State<HeadToHeadComparisonPage> createState() =>
      _HeadToHeadComparisonPageState();
}

class _HeadToHeadComparisonPageState extends State<HeadToHeadComparisonPage> {
  late Future<(PlayerProfile, PlayerProfile)> _profiles = _load();

  Future<(PlayerProfile, PlayerProfile)> _load() async {
    final repo = sl<CommunityRepository>();
    final results = await Future.wait([
      repo.getMyProfile(),
      repo.getPlayerProfile(widget.friend.userId),
    ]);
    return (results[0], results[1]);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'Compare'),
      onRefresh: () async {
        setState(() {
          _profiles = _load();
        });
        await _profiles;
      },
      body: FutureBuilder<(PlayerProfile, PlayerProfile)>(
        future: _profiles,
        builder: (context, snap) {
          if (snap.hasError) {
            final error = snap.error;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error is PlayerProfileException)
                  AppInfoNote(message: error.message),
                LoadErrorView(
                  onRetry: () => setState(() {
                    _profiles = _load();
                  }),
                ),
              ],
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Padding(
              padding: EdgeInsets.only(top: AppDimens.space48),
              child: Center(child: VitalUpLoader()),
            );
          }
          final (me, them) = data;
          if (them.isPrivate) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Players(me: me, them: them),
                const SizedBox(height: AppDimens.space12),
                AppInfoNote(
                  message:
                      "@${them.username} keeps their stats private, so "
                      "there's nothing to compare.",
                  icon: Icons.lock_outline_rounded,
                ),
              ],
            );
          }
          String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
          final stats = <_Stat>[
            (
              label: 'Level',
              mine: me.level,
              theirs: them.level,
              format: (n) => '$n',
            ),
            (
              label: 'Total points',
              mine: me.totalPoints,
              theirs: them.totalPoints,
              format: _number.format,
            ),
            (
              label: 'Current streak',
              mine: me.currentStreak,
              theirs: them.currentStreak,
              format: days,
            ),
            (
              label: 'Best streak',
              mine: me.longestStreak,
              theirs: them.longestStreak,
              format: days,
            ),
            (
              label: 'Badges',
              mine: me.badgeCount,
              theirs: them.badgeCount,
              format: _number.format,
            ),
          ];
          final categories = <_Stat>[
            for (final c in ScoreCategory.scored)
              (
                label: c.label,
                mine: me.pointsIn(c),
                theirs: them.pointsIn(c),
                format: _number.format,
              ),
          ];
          final all = [...stats, ...categories];
          final ahead = all.where((s) => s.mine > s.theirs).length;
          final behind = all.where((s) => s.mine < s.theirs).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Players(me: me, them: them),
              const SizedBox(height: AppDimens.space12),
              Text(
                ahead == behind
                    ? "You're level on ${all.length} stats overall"
                    : ahead > behind
                    ? "You're ahead on $ahead of ${all.length} stats"
                    : '@${them.username} is ahead on $behind of ${all.length} stats',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
              const SizedBox(height: AppDimens.sectionGap),
              const AppSectionHeader('Overall'),
              _StatsCard(stats: stats),
              const SizedBox(height: AppDimens.sectionGap),
              const AppSectionHeader('Points by category'),
              _StatsCard(stats: categories),
            ],
          );
        },
      ),
    );
  }
}

class _Players extends StatelessWidget {
  final PlayerProfile me;
  final PlayerProfile them;

  const _Players({required this.me, required this.them});

  @override
  Widget build(BuildContext context) {
    Widget player(PlayerProfile p, String label) => Expanded(
      child: Column(
        children: [
          UserAvatar(
            username: p.username,
            url: p.avatarUrl,
            size: AppDimens.iconXxl,
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          Text(
            'Level ${p.level}',
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
    return AppCard(
      width: double.infinity,
      child: Row(
        children: [
          player(me, 'You'),
          Text(
            'vs',
            style: context.text.titleSmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          player(them, '@${them.username}'),
        ],
      ),
    );
  }
}

/// Rows of "mine · label · theirs"; the higher side is in primary.
class _StatsCard extends StatelessWidget {
  final List<_Stat> stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final divider = context.vColors.divider;
    TextStyle? value(bool leads) => context.text.titleSmall?.copyWith(
      color: leads ? context.colors.primary : context.colors.onSurface,
      fontWeight: leads ? FontWeight.w700 : null,
    );
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        children: [
          for (final s in stats) ...[
            if (s != stats.first)
              Divider(height: AppDimens.space16, color: divider),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.format(s.mine),
                    textAlign: TextAlign.center,
                    style: value(s.mine > s.theirs),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.label,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.format(s.theirs),
                    textAlign: TextAlign.center,
                    style: value(s.theirs > s.mine),
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
