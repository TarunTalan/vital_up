import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/leaderboard_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _points = NumberFormat.decimalPattern();

/// A community's leaderboard: period and category filters, a top-3 podium,
/// the ranked list and the caller's own rank pinned at the bottom.
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
  bool _membershipBusy = false;

  Future<void> _toggleMembership(Community community) async {
    final cubit = context.read<LeaderboardCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final repo = sl<CommunityRepository>();
    final joining = !community.isMember;
    setState(() => _membershipBusy = true);
    try {
      joining ? await repo.join(community) : await repo.leave(community);
      cubit.updateCommunity(
        community.copyWith(
          isMember: joining,
          memberCount: community.memberCount + (joining ? 1 : -1),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't ${joining ? 'join' : 'leave'} ${community.name}.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _membershipBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        final cubit = context.read<LeaderboardCubit>();
        final community = state.community;
        final entries = state.entries;
        final me = state.me;
        // Friends boards list players without points unranked.
        final podium =
            entries?.where((e) => e.rank != null).take(3).toList() ??
            const <LeaderboardEntry>[];
        final rest =
            entries?.skip(podium.length).toList() ?? const <LeaderboardEntry>[];

        return AppScaffold(
          header: AppPageHeader(
            title: community.name,
            subtitle: community.rankedOn,
            action: community.type == CommunityType.friends
                ? AppHeaderAction(
                    tooltip: 'Add friends',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onTap: () async {
                      await context.pushNamed('friends');
                      cubit.load();
                    },
                  )
                : null,
          ),
          bottomBar: me == null || entries == null
              ? null
              : _MyRankBar(entry: me),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (community.description != null)
                Text(
                  community.description!,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              if (community.canJoin) ...[
                const SizedBox(height: AppDimens.space12),
                community.isMember
                    ? AppSecondaryButton(
                        label: 'Leave community',
                        isLoading: _membershipBusy,
                        onTap: () => _toggleMembership(community),
                      )
                    : AppPrimaryButton(
                        label: 'Join community',
                        isLoading: _membershipBusy,
                        onTap: () => _toggleMembership(community),
                      ),
              ],
              const SizedBox(height: AppDimens.cardInnerGap),
              SegmentedButton<LeaderboardPeriod>(
                showSelectedIcon: false,
                segments: [
                  for (final p in LeaderboardPeriod.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {state.period},
                onSelectionChanged: (s) => cubit.setPeriod(s.first),
              ),
              if (state.categories.isNotEmpty) ...[
                const SizedBox(height: AppDimens.space12),
                Wrap(
                  spacing: AppDimens.space8,
                  runSpacing: AppDimens.space8,
                  children: [
                    ChoiceChip(
                      label: const Text('Overall'),
                      selected: state.category == null,
                      showCheckmark: false,
                      onSelected: (_) => cubit.setCategory(null),
                    ),
                    for (final c in state.categories)
                      ChoiceChip(
                        avatar: Icon(
                          c.icon,
                          size: AppDimens.iconXs,
                          color: c.color,
                        ),
                        label: Text(c.label),
                        selected: state.category == c,
                        showCheckmark: false,
                        onSelected: (_) => cubit.setCategory(c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimens.sectionGap),
              if (entries == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space24),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: CircularProgressIndicator()),
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
              else ...[
                if (state.loading) const LinearProgressIndicator(),
                _Podium(entries: podium),
                const SizedBox(height: AppDimens.cardInnerGap),
                for (final e in rest) ...[
                  _RankRow(entry: e),
                  const SizedBox(height: AppDimens.space8),
                ],
                if (state.hasMore)
                  AppSecondaryButton(
                    label: 'Show more',
                    isLoading: state.loadingMore,
                    onTap: cubit.loadMore,
                  ),
              ],
            ],
          ),
        );
      },
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

  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? at(int i) => i < entries.length ? entries[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumPlace(entry: at(1), step: AppDimens.podiumStepSecond),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: _PodiumPlace(
            entry: at(0),
            step: AppDimens.podiumStepFirst,
            first: true,
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: _PodiumPlace(entry: at(2), step: AppDimens.podiumStepThird),
        ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final LeaderboardEntry? entry;
  final double step;
  final bool first;

  const _PodiumPlace({
    required this.entry,
    required this.step,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();
    final color = _rankColor(e.rank ?? 3);
    return Column(
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
          '${_points.format(e.points)} pts',
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
          child: Text(
            '${e.rank}',
            style: context.text.headlineSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool pinned;

  const _RankRow({required this.entry, this.pinned = false});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final onSurface = context.colors.onSurface;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      highlighted: e.isMe,
      child: Row(
        children: [
          SizedBox(
            width: AppDimens.rankColumnWidth,
            child: Text(
              e.rank == null ? '–' : '${e.rank}',
              style: context.text.titleSmall?.copyWith(color: onSurface),
            ),
          ),
          UserAvatar(username: e.username, url: e.avatarUrl),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.isMe ? '${e.username} (you)' : e.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(color: onSurface),
                ),
                Text(
                  pinned && e.rank == null
                      ? 'Earn points to get ranked'
                      : 'Level ${e.level}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_points.format(e.points)} pts',
            style: context.text.titleSmall?.copyWith(
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRankBar extends StatelessWidget {
  final LeaderboardEntry entry;

  const _MyRankBar({required this.entry});

  @override
  Widget build(BuildContext context) => _RankRow(entry: entry, pinned: true);
}
