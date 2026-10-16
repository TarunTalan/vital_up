import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/leaderboard_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/community/presentation/widgets/public_profile_sheet.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _points = NumberFormat.decimalPattern();

/// A community's leaderboard: one line of filters, a top-3 podium and the
/// next players, then the caller and their friends further down with their
/// real ranks, and the period's awards (countdown to the winners, rules,
/// last winners). Join shows as a banner; About and Leave sit behind the
/// header's More button.
class LeaderboardPage extends StatelessWidget {
  final Community community;

  const LeaderboardPage({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LeaderboardCubit(sl<CommunityRepository>(), community)..load(),
      child: const _LeaderboardView(),
    );
  }
}

class _LeaderboardView extends StatefulWidget {
  const _LeaderboardView();

  @override
  State<_LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<_LeaderboardView> {
  /// Players shown before "Show more"; grows by [_step].
  static const _initialShown = 10;
  static const _step = 20;

  int _shown = _initialShown;
  bool _membershipBusy = false;

  Future<void> _setMembership(Community community, {required bool join}) async {
    final cubit = context.read<LeaderboardCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final repo = sl<CommunityRepository>();
    if (_membershipBusy) return;
    setState(() => _membershipBusy = true);
    try {
      join ? await repo.join(community) : await repo.leave(community);
      // Left the page meanwhile: its cubit is closed.
      if (!mounted) return;
      cubit.updateCommunity(
        community.copyWith(
          isMember: join,
          memberCount: community.memberCount + (join ? 1 : -1),
        ),
      );
    } catch (e) {
      debugPrint('Membership change failed: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessage(
              e,
              fallback: join
                  ? "Couldn't join. Try again."
                  : "Couldn't leave. Try again.",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _membershipBusy = false);
    }
  }

  Future<void> _confirmLeave(Community community) async {
    final errorColor = context.colors.error;
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${community.name}?'),
        content: const Text(
          "You'll drop off this leaderboard. You can join again any time.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _setMembership(community, join: false);
  }

  /// About the community, and Leave for joined interest communities. The
  /// sheet returns true for Leave; the confirmation opens once it's closed.
  Future<void> _openMenu(Community community) async {
    final leave = await showAppBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => _CommunityMenu(
        community: community,
        onLeave: community.canJoin && community.isMember
            ? () => Navigator.of(sheetContext).pop(true)
            : null,
      ),
    );
    if (leave == true && mounted) await _confirmLeave(community);
  }

  void _showMore(LeaderboardState state) {
    setState(() => _shown += _step);
    if (_shown > (state.entries?.length ?? 0) && state.hasMore) {
      context.read<LeaderboardCubit>().loadMore();
    }
  }

  Widget? _headerAction(Community community, LeaderboardCubit cubit) {
    if (community.type == CommunityType.friends) {
      return AppHeaderAction(
        tooltip: 'Add friends',
        icon: const Icon(Icons.person_add_alt_1_rounded),
        onTap: () async {
          await context.pushNamed('friends');
          cubit.load();
        },
      );
    }
    final hasMenu =
        (community.description?.isNotEmpty ?? false) ||
        (community.canJoin && community.isMember);
    if (!hasMenu) return null;
    return AppHeaderAction(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz_rounded),
      onTap: () => _openMenu(community),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeaderboardCubit, LeaderboardState>(
      // A new filter starts from the top ten again.
      listenWhen: (prev, next) =>
          prev.period != next.period || prev.category != next.category,
      listener: (_, _) => setState(() => _shown = _initialShown),
      builder: (context, state) {
        final cubit = context.read<LeaderboardCubit>();
        final community = state.community;
        final entries = state.entries;
        final members = community.memberCount;

        return AppScaffold(
          onRefresh: () async => cubit.load(),
          header: AppPageHeader(
            title: community.name,
            subtitle:
                '${_points.format(members)} '
                '${members == 1 ? 'member' : 'members'} · '
                '${community.rankedOn}',
            action: _headerAction(community, cubit),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (community.canJoin && !community.isMember) ...[
                _JoinBanner(
                  busy: _membershipBusy,
                  onJoin: () => _setMembership(community, join: true),
                ),
                const SizedBox(height: AppDimens.space16),
              ],
              _Filters(state: state, cubit: cubit),
              const SizedBox(height: AppDimens.space16),
              if (state.loading && entries != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppDimens.space8),
                  child: LinearProgressIndicator(),
                ),
              if (entries == null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.space32,
                  ),
                  child: Center(
                    child: state.failed
                        ? LoadErrorView(onRetry: cubit.load)
                        : const VitalUpLoader(),
                  ),
                )
              else if (community.type == CommunityType.friends &&
                  entries.length <= 1)
                const AppInfoNote(
                  message:
                      'Add friends by username to see how you rank '
                      'against them.',
                )
              else if (entries.isEmpty)
                const AppInfoNote(
                  message:
                      'No points here yet this period. Log meals, water, '
                      'sleep or a workout to take the top spot.',
                )
              else
                ..._board(state, entries),
              if (entries != null &&
                  community.type != CommunityType.friends &&
                  state.awardPeriod != null) ...[
                const SizedBox(height: AppDimens.space16),
                LeaderboardAwardsCard(
                  period: state.awardPeriod!,
                  winners: state.pastWinners,
                  onOpenPlayer: (w) => PublicProfileSheet.show(
                    context,
                    username: w.username,
                    level: w.level,
                    avatarUrl: w.avatarUrl,
                    userId: w.userId,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Podium, the next players up to [_shown], then the caller and their
  /// friends who sit further down, with their real ranks.
  List<Widget> _board(LeaderboardState state, List<LeaderboardEntry> entries) {
    final top = entries.take(_shown).toList();
    // Friends boards list players without points unranked.
    final podium = top.where((e) => e.rank != null).take(3).toList();
    final rest = top.skip(podium.length).toList();
    final friendIds = state.friendIds;
    final shownIds = {for (final e in top) e.userId};
    final below = [
      for (final e
          in state.friendRanks.isNotEmpty ? state.friendRanks : [?state.me])
        if (!shownIds.contains(e.userId)) e,
    ];
    final canShowMore = entries.length > _shown || state.hasMore;

    return [
      _Podium(entries: podium, friendIds: friendIds),
      if (rest.isNotEmpty) ...[
        const SizedBox(height: AppDimens.space16),
        AppListGroup(
          children: [
            for (final e in rest)
              _RankRow(entry: e, isFriend: friendIds.contains(e.userId)),
          ],
        ),
      ],
      if (canShowMore) ...[
        const SizedBox(height: AppDimens.space8),
        Center(
          child: state.loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(AppDimens.space8),
                  child: SizedBox.square(
                    dimension: AppDimens.iconLg,
                    child: CircularProgressIndicator(
                      strokeWidth: AppDimens.borderThick,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: () => _showMore(state),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Show more'),
                ),
        ),
      ],
      if (below.isNotEmpty) ...[
        const SizedBox(height: AppDimens.space16),
        AppListGroup(
          title: below.any((e) => !e.isMe) ? 'You and your friends' : 'You',
          children: [
            for (final e in below)
              _RankRow(entry: e, isFriend: friendIds.contains(e.userId)),
          ],
        ),
      ],
    ];
  }
}

/// One scrolling line of filters: the period as a menu chip, then the
/// categories this board can rank on.
class _Filters extends StatelessWidget {
  final LeaderboardState state;
  final LeaderboardCubit cubit;

  const _Filters({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          PopupMenuButton<LeaderboardPeriod>(
            tooltip: 'Period',
            initialValue: state.period,
            onSelected: cubit.setPeriod,
            itemBuilder: (_) => [
              for (final p in LeaderboardPeriod.values)
                PopupMenuItem(value: p, child: Text(p.label)),
            ],
            child: _ChipLook(
              selected: true,
              icon: Icons.calendar_today_rounded,
              label: state.period.label,
              trailing: Icons.expand_more_rounded,
            ),
          ),
          if (state.categories.isNotEmpty) ...[
            Container(
              width: AppDimens.borderThin,
              height: AppDimens.iconLg,
              margin: const EdgeInsets.symmetric(horizontal: AppDimens.space8),
              color: context.vColors.divider,
            ),
            _CategoryChip(
              label: 'Overall',
              selected: state.category == null,
              onTap: () => cubit.setCategory(null),
            ),
            for (final c in state.categories) ...[
              const SizedBox(width: AppDimens.space8),
              _CategoryChip(
                label: c.label,
                icon: c.icon,
                iconColor: c.color,
                selected: state.category == c,
                onTap: () => cubit.setCategory(c),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: _ChipLook(
          selected: selected,
          icon: icon,
          iconColor: iconColor,
          label: label,
        ),
      ),
    );
  }
}

/// Pill used by the filters: tinted and outlined when selected.
class _ChipLook extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final IconData? trailing;

  const _ChipLook({
    required this.selected,
    required this.label,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final fg = selected ? v.accentText : context.colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space8,
      ),
      decoration: BoxDecoration(
        color: selected ? v.primaryFill : v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: selected ? v.primaryBorder! : v.glassBorder!,
          width: AppDimens.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppDimens.iconXs, color: iconColor ?? fg),
            const SizedBox(width: AppDimens.space6),
          ],
          Text(label, style: context.text.labelLarge?.copyWith(color: fg)),
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.space2),
            Icon(trailing, size: AppDimens.iconSm, color: fg),
          ],
        ],
      ),
    );
  }
}

/// Shown to people who haven't joined an interest community yet.
class _JoinBanner extends StatelessWidget {
  final bool busy;
  final VoidCallback onJoin;

  const _JoinBanner({required this.busy, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      highlighted: true,
      padding: AppDimens.cardPaddingCompact,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Join to appear on this leaderboard',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          busy
              ? const SizedBox.square(
                  dimension: AppDimens.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimens.borderThick,
                    strokeCap: StrokeCap.round,
                  ),
                )
              : FilledButton(onPressed: onJoin, child: const Text('Join')),
        ],
      ),
    );
  }
}

/// Sheet behind the header "More" button: what the community is about,
/// and Leave when the caller joined it.
class _CommunityMenu extends StatelessWidget {
  final Community community;
  final VoidCallback? onLeave;

  const _CommunityMenu({required this.community, this.onLeave});

  @override
  Widget build(BuildContext context) {
    final description = community.description;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(community.name, style: context.text.headlineSmall),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: AppDimens.space8),
              Text(
                description,
                style: context.text.bodyMedium?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.space8),
            Text(
              'Ranks on ${community.rankedOn.toLowerCase()}',
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            if (onLeave != null) ...[
              const SizedBox(height: AppDimens.space16),
              AppListGroup(
                children: [
                  AppListTile(
                    icon: Icons.logout_rounded,
                    title: 'Leave community',
                    destructive: true,
                    onTap: onLeave,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _rankColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// Top three, 2nd – 1st – 3rd, on stepped plinths.
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final Set<String> friendIds;

  const _Podium({required this.entries, this.friendIds = const {}});

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? at(int i) => i < entries.length ? entries[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumPlace(
            entry: at(1),
            step: AppDimens.podiumStepSecond,
            friendIds: friendIds,
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: _PodiumPlace(
            entry: at(0),
            step: AppDimens.podiumStepFirst,
            first: true,
            friendIds: friendIds,
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: _PodiumPlace(
            entry: at(2),
            step: AppDimens.podiumStepThird,
            friendIds: friendIds,
          ),
        ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final LeaderboardEntry? entry;
  final double step;
  final bool first;
  final Set<String> friendIds;

  const _PodiumPlace({
    required this.entry,
    required this.step,
    this.first = false,
    this.friendIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();
    final color = _rankColor(e.rank ?? 3);
    return GestureDetector(
      onTap: () {
        if (!e.isMe) {
          PublicProfileSheet.show(
            context,
            username: e.username,
            level: e.level,
            avatarUrl: e.avatarUrl,
            userId: e.userId,
            points: e.points,
            rank: e.rank,
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (first)
            GameIcon(
              GamificationIcons.crown,
              fallback: Icons.workspace_premium_rounded,
              size: AppDimens.iconXl,
              color: color,
            ),
          UserAvatar(
            username: e.username,
            url: e.avatarUrl,
            size: first
                ? AppDimens.podiumAvatarFirst
                : AppDimens.podiumAvatarOther,
            ringColor: color,
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            e.isMe ? 'You' : e.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          Text(
            friendIds.contains(e.userId)
                ? 'Friend · ${_points.format(e.points)} pts'
                : '${_points.format(e.points)} pts',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space6),
          Container(
            height: step,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusSm),
              ),
            ),
            child: e.rank != null && e.rank! <= 3
                ? GameIcon(
                    GamificationIcons.leaderboardRank(e.rank!)!,
                    fallback: Icons.military_tech_rounded,
                    size: 28,
                    color: color,
                  )
                : Text(
                    '${e.rank}',
                    style: context.text.headlineSmall?.copyWith(color: color),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One player inside an [AppListGroup]: rank (medal for the top three),
/// avatar, name with "Friend" or "Level n", and points. The caller's row is
/// tinted.
class _RankRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isFriend;

  const _RankRow({required this.entry, this.isFriend = false});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final rank = e.rank;
    final grey = context.vColors.grayText;
    return Material(
      color: e.isMe ? context.vColors.primaryTint : Colors.transparent,
      child: InkWell(
        onTap: e.isMe
            ? null
            : () => PublicProfileSheet.show(
                context,
                username: e.username,
                level: e.level,
                avatarUrl: e.avatarUrl,
                userId: e.userId,
                points: e.points,
                rank: e.rank,
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space10,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppDimens.rankColumnWidth + AppDimens.space8,
                child: rank != null && rank <= 3
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: GameIcon(
                          GamificationIcons.leaderboardRank(rank)!,
                          fallback: Icons.military_tech_rounded,
                          size: AppDimens.iconLg,
                          color: _rankColor(rank),
                        ),
                      )
                    : Text(
                        rank == null ? '–' : _points.format(rank),
                        style: context.text.titleSmall?.copyWith(
                          color: e.isMe
                              ? context.vColors.accentText
                              : context.colors.onSurface,
                        ),
                      ),
              ),
              UserAvatar(
                username: e.username,
                url: e.avatarUrl,
                ringColor: e.isMe ? context.colors.primary : null,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.isMe ? '${e.username} (you)' : e.username,
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      e.isMe && rank == null
                          ? 'Earn points to get ranked'
                          : isFriend
                          ? 'Friend · Level ${e.level}'
                          : 'Level ${e.level}',
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Text(
                '${_points.format(e.points)} pts',
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
