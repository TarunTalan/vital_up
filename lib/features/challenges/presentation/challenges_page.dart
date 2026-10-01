import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

IconData _metricIcon(ChallengeMetric m) => switch (m) {
  ChallengeMetric.activeMinutes => Icons.timer_rounded,
  ChallengeMetric.distanceKm => Icons.route_rounded,
  ChallengeMetric.workouts => Icons.fitness_center_rounded,
};

String _timeLeft(DateTime endsAt) {
  final left = endsAt.difference(DateTime.now());
  if (left.isNegative) return 'Ended';
  if (left.inDays >= 1) {
    return '${left.inDays} ${left.inDays == 1 ? 'day' : 'days'} left';
  }
  if (left.inHours >= 1) return '${left.inHours} h left';
  return 'Ends soon';
}

/// Friend challenges: invites, active and finished contests, and a button to
/// start a new one.
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChallengesCubit, ChallengesState>(
      listenWhen: (prev, next) => next.messageId != prev.messageId,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<ChallengesCubit>();
        final challenges = state.challenges;
        final now = DateTime.now();
        return AppScaffold(
          header: const AppPageHeader(title: 'Challenges'),
          bottomBar: AppPrimaryButton(
            label: 'New challenge',
            leadingIcon: const Icon(Icons.add_rounded),
            onTap: () => showAppBottomSheet<void>(
              context: context,
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: const _CreateChallengeSheet(),
              ),
            ),
          ),
          body: challenges == null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space48),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: VitalUpLoader()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (challenges.isEmpty)
                      const AppInfoNote(
                        message:
                            'Challenge friends to the most active minutes, '
                            'distance or workouts over 3, 7 or 14 days. '
                            'Workouts count once they are backed up.',
                        icon: Icons.emoji_events_outlined,
                      ),
                    for (final (title, items) in [
                      (
                        'Active',
                        challenges.where((c) => c.isActiveAt(now)).toList(),
                      ),
                      (
                        'Finished',
                        challenges.where((c) => !c.isActiveAt(now)).toList(),
                      ),
                    ])
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.space8),
                        AppCaption(title),
                        const SizedBox(height: AppDimens.space8),
                        for (final c in items) ...[
                          _ChallengeTile(
                            challenge: c,
                            busy: state.busy.contains(c.id),
                          ),
                          const SizedBox(height: AppDimens.cardGap),
                        ],
                      ],
                  ],
                ),
        );
      },
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  final bool busy;

  const _ChallengeTile({required this.challenge, required this.busy});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final cubit = context.read<ChallengesCubit>();
    final invited = c.myStatus == ParticipantStatus.invited;
    final active = c.isActiveAt(DateTime.now());
    final v = context.vColors;
    return AppCard(
      width: double.infinity,
      onTap: invited
          ? null
          : () => showAppBottomSheet<void>(
              context: context,
              builder: (_) => _LeaderboardSheet(challenge: c),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icon(_metricIcon(c.metric)),
                color: AppColors.scoreFitness,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Most ${c.metric.label.toLowerCase()} · '
                      '${c.endsAt.difference(c.startsAt).inDays} days',
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'by @${c.creatorUsername} · ${c.participants} in · '
                      '${_timeLeft(c.endsAt)}',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              if (!invited && c.myRank != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '#${c.myRank}',
                      style: context.text.titleMedium?.copyWith(
                        color: c.myRank == 1 ? AppColors.rankGold : null,
                      ),
                    ),
                    Text(
                      c.metric.format(c.myScore ?? 0),
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (invited && active) ...[
            const SizedBox(height: AppDimens.space12),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Decline',
                    enabled: !busy,
                    onTap: () => cubit.respond(c, accept: false),
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Join',
                    isLoading: busy,
                    onTap: () => cubit.respond(c, accept: true),
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

/// Live standings of one challenge.
class _LeaderboardSheet extends StatelessWidget {
  final Challenge challenge;

  const _LeaderboardSheet({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: FutureBuilder<List<ChallengeStanding>>(
          future: sl<ChallengesRepository>().getLeaderboard(challenge.id),
          builder: (context, snap) {
            final standings = snap.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Most ${challenge.metric.label.toLowerCase()}',
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: AppDimens.space4),
                Text(
                  _timeLeft(challenge.endsAt),
                  style: context.text.bodySmall?.copyWith(color: v.grayText),
                ),
                const SizedBox(height: AppDimens.space16),
                if (snap.hasError)
                  Text(
                    snap.error.toString(),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  )
                else if (standings == null)
                  const Padding(
                    padding: EdgeInsets.all(AppDimens.space24),
                    child: Center(child: VitalUpLoader()),
                  )
                else
                  for (final s in standings)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.space8,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: AppDimens.space32,
                            child: Text(
                              s.rank == null ? '–' : '#${s.rank}',
                              style: context.text.titleSmall,
                            ),
                          ),
                          UserAvatar(username: s.username, url: s.avatarUrl),
                          const SizedBox(width: AppDimens.space12),
                          Expanded(
                            child: Text(
                              s.isMe
                                  ? '@${s.username} (you)'
                                  : '@${s.username}',
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: s.isMe ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                          Text(
                            s.status == ParticipantStatus.invited
                                ? 'Invited'
                                : challenge.metric.format(s.score ?? 0),
                            style: context.text.titleSmall?.copyWith(
                              color: s.status == ParticipantStatus.invited
                                  ? v.grayText
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Metric, duration and friends for a new challenge.
class _CreateChallengeSheet extends StatefulWidget {
  const _CreateChallengeSheet();

  @override
  State<_CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<_CreateChallengeSheet> {
  static const _durations = [3, 7, 14];
  static const _maxFriends = 9;

  final _friends = sl<CommunityRepository>().getFriends();
  ChallengeMetric _metric = ChallengeMetric.activeMinutes;
  int _days = 7;
  final _picked = <String>{};
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await context.read<ChallengesCubit>().create(
      metric: _metric,
      days: _days,
      friendIds: _picked.toList(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
            Text('New challenge', style: context.text.headlineSmall),
            const SizedBox(height: AppDimens.sectionGap),
            Text('Most…', style: context.text.titleSmall),
            const SizedBox(height: AppDimens.space8),
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: [
                for (final m in ChallengeMetric.values)
                  ChoiceChip(
                    avatar: Icon(_metricIcon(m), size: AppDimens.iconSm),
                    label: Text(m.label),
                    selected: _metric == m,
                    onSelected: (_) => setState(() => _metric = m),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.space16),
            Text('For', style: context.text.titleSmall),
            const SizedBox(height: AppDimens.space8),
            Wrap(
              spacing: AppDimens.space8,
              children: [
                for (final d in _durations)
                  ChoiceChip(
                    label: Text('$d days'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.space16),
            Text(
              'Friends (${_picked.length}/$_maxFriends)',
              style: context.text.titleSmall,
            ),
            const SizedBox(height: AppDimens.space8),
            FutureBuilder<List<Friend>>(
              future: _friends,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    "Couldn't load your friends.",
                    style: context.text.bodyMedium?.copyWith(color: v.grayText),
                  );
                }
                final friends = snap.data
                    ?.where((f) => f.status == FriendStatus.accepted)
                    .toList();
                if (friends == null) {
                  return const Center(child: VitalUpLoader());
                }
                if (friends.isEmpty) {
                  return const AppInfoNote(
                    message:
                        'Add friends in Community first, then challenge them.',
                  );
                }
                return Column(
                  children: [
                    for (final f in friends)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _picked.contains(f.userId),
                        onChanged:
                            _picked.contains(f.userId) ||
                                _picked.length < _maxFriends
                            ? (on) => setState(
                                () => on == true
                                    ? _picked.add(f.userId)
                                    : _picked.remove(f.userId),
                              )
                            : null,
                        secondary: UserAvatar(
                          username: f.username,
                          url: f.avatarUrl,
                        ),
                        title: Text('@${f.username}'),
                      ),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.space8),
              Text(
                _error!,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Send challenge',
              isLoading: _sending,
              enabled: _picked.isNotEmpty,
              onTap: _send,
            ),
          ],
        ),
      ),
    );
  }
}
