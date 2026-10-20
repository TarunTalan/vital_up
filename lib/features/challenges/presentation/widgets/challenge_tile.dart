import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/core/widgets/name_with_you_tag.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

IconData challengeMetricIcon(ChallengeMetric m) => switch (m) {
  ChallengeMetric.activeMinutes => Icons.timer_rounded,
  ChallengeMetric.distanceKm => Icons.route_rounded,
  ChallengeMetric.workouts => Icons.fitness_center_rounded,
  ChallengeMetric.xp => Icons.star_rounded,
};

String challengeTimeLeft(DateTime endsAt) {
  final left = endsAt.difference(DateTime.now());
  if (left.isNegative) return 'Ended';
  if (left.inDays >= 1) {
    return '${left.inDays} ${left.inDays == 1 ? 'day' : 'days'} left';
  }
  if (left.inHours >= 1) return '${left.inHours} h left';
  return 'Ends soon';
}

/// Still running and you're in it (invited or joined).
bool challengeIsOpen(Challenge c, DateTime now) =>
    c.isActiveAt(now) &&
    (c.myStatus == ParticipantStatus.invited ||
        c.myStatus == ParticipantStatus.joined);

/// Second line of a challenge tile: who, how many and when, or how it
/// ended for you. [withTimeLeft] false drops the time left (a running
/// tile shows it under its progress bar).
String challengeSubtitle(
  Challenge c,
  DateTime now, {
  bool withTimeLeft = true,
}) {
  final people =
      '${c.participants} ${c.participants == 1 ? 'person' : 'people'}';
  if (c.myStatus == ParticipantStatus.left) {
    return 'by @${c.creatorUsername} · $people';
  }
  if (!c.isActiveAt(now)) {
    return 'Ended ${DateFormat('d MMM').format(c.endsAt)} · $people';
  }
  final from = c.myStatus == ParticipantStatus.invited ? 'Invite from' : 'by';
  return [
    '$from @${c.creatorUsername}',
    people,
    if (withTimeLeft) challengeTimeLeft(c.endsAt),
  ].join(' · ');
}

/// Whole days the challenge runs. Nearest whole day: in local time a week
/// across a clock change is 6 days 23 h, which inDays would call "6 days".
int challengeDays(Challenge c) =>
    (c.endsAt.difference(c.startsAt).inHours / 24).round().clamp(1, 365);

String challengeTitle(Challenge c) =>
    'Most ${c.metric.label.toLowerCase()} · ${challengeDays(c)} days';

/// Share of a running challenge's time that has passed (0-1).
double challengeElapsed(Challenge c, DateTime now) {
  final total = c.endsAt.difference(c.startsAt).inSeconds;
  if (total <= 0) return 1;
  return (now.difference(c.startsAt).inSeconds / total).clamp(0.0, 1.0);
}

/// "Day 3 of 7" for a running challenge.
String challengeDayLabel(Challenge c, DateTime now) {
  final days = challengeDays(c);
  final day = (now.difference(c.startsAt).inHours ~/ 24 + 1).clamp(1, days);
  return 'Day $day of $days';
}

Color _medalColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// One challenge. Running ones lead with the brand colour and a bar of the
/// time gone ("Day 3 of 7 · 4 days left"); finished ones are grey and say
/// how they ended ("You won", "Finished", "You left"). Your rank and score
/// sit on the right once you've joined. An open invite shows Decline /
/// Join; anything else opens the standings, where a running challenge can
/// be left. Needs a [ChallengesCubit] above.
class ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  final bool busy;

  const ChallengeTile({super.key, required this.challenge, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final cubit = context.read<ChallengesCubit>();
    final invited = c.myStatus == ParticipantStatus.invited;
    final now = DateTime.now();
    final active = c.isActiveAt(now);
    final left = c.myStatus == ParticipantStatus.left;
    final running = active && !left && !invited;
    final finished = !active || left;
    final grey = context.vColors.grayText!;
    final rank = c.myRank;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: invited ? null : () => ChallengeStandingsSheet.show(context, c),
      showChevron: !invited,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icon(challengeMetricIcon(c.metric)),
                color: finished ? grey : context.colors.primary,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challengeTitle(c),
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      challengeSubtitle(c, now, withTimeLeft: !running),
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (running || finished) ...[
            const SizedBox(height: AppDimens.space12),
            if (running) ...[
              AppProgressBar(
                value: challengeElapsed(c, now),
                color: context.colors.primary,
              ),
              const SizedBox(height: AppDimens.space8),
            ],
            // Status at the start, your place at the end; the place moves
            // under the status when both don't fit (large text).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: [
                if (running)
                  Text(
                    '${challengeDayLabel(c, now)} · '
                    '${challengeTimeLeft(c.endsAt)}',
                    style: context.text.bodySmall?.copyWith(color: grey),
                  )
                else if (left)
                  const TrackerStatusChip(
                    TrackerStatus.notLogged,
                    label: 'You left',
                    icon: Icons.logout_rounded,
                  )
                else if (rank == 1)
                  const TrackerStatusChip(
                    TrackerStatus.done,
                    label: 'You won',
                    icon: Icons.emoji_events_rounded,
                  )
                else
                  const TrackerStatusChip(
                    TrackerStatus.notLogged,
                    label: 'Finished',
                    icon: Icons.flag_rounded,
                  ),
                if (!left && rank != null)
                  _RankFigure(
                    rank: rank,
                    score: c.metric.format(c.myScore ?? 0),
                  ),
              ],
            ),
          ],
          if (invited && active) ...[
            const SizedBox(height: AppDimens.cardInnerGap),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Decline',
                    enabled: !busy,
                    onTap: () => cubit.respond(c, accept: false),
                  ),
                ),
                const SizedBox(width: AppDimens.buttonGap),
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

/// Your place and score on a challenge tile: the medal for the top three
/// (the number would repeat it), otherwise "#5", then the score.
class _RankFigure extends StatelessWidget {
  final int rank;
  final String score;

  const _RankFigure({required this.rank, required this.score});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rank $rank, $score',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank <= 3)
            GameIcon(
              GamificationIcons.leaderboardRank(rank)!,
              fallback: Icons.military_tech_rounded,
              size: AppDimens.iconMd,
              color: _medalColor(rank),
            )
          else
            Text(
              '#$rank',
              style: context.text.titleSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          const SizedBox(width: AppDimens.space4),
          Text(
            score,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standings of one challenge, with Leave while it's running and you're in.
class ChallengeStandingsSheet extends StatefulWidget {
  final Challenge challenge;

  const ChallengeStandingsSheet({super.key, required this.challenge});

  static Future<void> show(BuildContext context, Challenge challenge) {
    final cubit = context.read<ChallengesCubit>();
    return showAppBottomSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ChallengeStandingsSheet(challenge: challenge),
      ),
    );
  }

  @override
  State<ChallengeStandingsSheet> createState() =>
      _ChallengeStandingsSheetState();
}

class _ChallengeStandingsSheetState extends State<ChallengeStandingsSheet> {
  // Created once so rebuilds (e.g. the sheet resizing) don't refetch.
  late Future<List<ChallengeStanding>> _standings = _fetch();

  Future<List<ChallengeStanding>> _fetch() =>
      sl<ChallengesRepository>().getLeaderboard(widget.challenge.id);

  Future<void> _leave() async {
    final cubit = context.read<ChallengesCubit>();
    final navigator = Navigator.of(context);
    final errorColor = context.colors.error;
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave challenge?'),
        content: const Text(
          "You'll drop off the standings and can't rejoin. It stays in your "
          'history.',
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
    if (ok != true || !mounted) return;
    // The sheet may be gone by then; don't pop whatever is underneath.
    if (await cubit.leave(widget.challenge) && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final grey = context.vColors.grayText;
    final canLeave =
        challenge.myStatus == ParticipantStatus.joined &&
        challenge.isActiveAt(DateTime.now());
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
          future: _standings,
          builder: (context, snap) {
            final standings = snap.data;
            // Up to 10 participants plus the Leave button: scroll on short
            // phones and with large text.
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    challengeTitle(challenge),
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: AppDimens.space4),
                  Text(
                    challengeSubtitle(challenge, DateTime.now()),
                    style: context.text.bodySmall?.copyWith(color: grey),
                  ),
                  const SizedBox(height: AppDimens.space16),
                  if (snap.hasError)
                    LoadErrorView(
                      onRetry: () => setState(() {
                        _standings = _fetch();
                      }),
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
                            Container(
                              width: AppDimens.rankColumnWidth,
                              margin: const EdgeInsets.only(
                                right: AppDimens.space8,
                              ),
                              alignment: AlignmentDirectional.centerStart,
                              child: s.rank != null && s.rank! <= 3
                                  ? GameIcon(
                                      GamificationIcons.leaderboardRank(
                                        s.rank!,
                                      )!,
                                      fallback: Icons.military_tech_rounded,
                                      size: AppDimens.iconLg,
                                      color: _medalColor(s.rank!),
                                    )
                                  : FitText(
                                      s.rank == null ? '–' : '#${s.rank}',
                                      textAlign: TextAlign.center,
                                      style: context.text.titleSmall,
                                    ),
                            ),
                            UserAvatar(username: s.username, url: s.avatarUrl),
                            const SizedBox(width: AppDimens.space12),
                            Expanded(
                              child: NameWithYouTag(
                                name: '@${s.username}',
                                isMe: s.isMe,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: s.isMe ? FontWeight.w600 : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.space8),
                            Text(
                              s.status == ParticipantStatus.invited
                                  ? 'Invited'
                                  : challenge.metric.format(s.score ?? 0),
                              style: context.text.titleSmall?.copyWith(
                                color: s.status == ParticipantStatus.invited
                                    ? grey
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (canLeave) ...[
                    const SizedBox(height: AppDimens.space16),
                    BlocSelector<ChallengesCubit, ChallengesState, bool>(
                      selector: (state) => state.busy.contains(challenge.id),
                      builder: (context, busy) => AppSecondaryButton(
                        label: 'Leave challenge',
                        leadingIcon: Icon(
                          Icons.logout_rounded,
                          size: AppDimens.iconSm,
                          color: context.colors.error,
                        ),
                        contentColor: context.colors.error,
                        isLoading: busy,
                        onTap: _leave,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Selectable row for single-choice lists in challenge sheets: icon badge,
/// title and a radio mark; the selected row is outlined in primary.
class ChallengeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const ChallengeOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final grey = context.vColors.grayText;
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        width: double.infinity,
        padding: AppDimens.cardPaddingCompact,
        borderColor: selected ? primary : null,
        tint: selected ? context.vColors.primaryFill : null,
        onTap: onTap,
        child: Row(
          children: [
            AppIconBadge(icon: Icon(icon), color: primary),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: AppDimens.iconMd,
              color: selected ? primary : grey,
            ),
          ],
        ),
      ),
    );
  }
}
