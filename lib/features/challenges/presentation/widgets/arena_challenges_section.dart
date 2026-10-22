import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/challenges/presentation/widgets/custom_challenge_wizard.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

/// Arena section, kept short: at most [_maxShown] items, open invites
/// first as one-line rows with Join (Decline is on the Challenges page),
/// then running challenges, and a "New challenge" link under them; the rest
/// (more invites, finished ones) live behind "See all" (the title counts
/// them all when some are left out).
class ArenaChallengesSection extends StatelessWidget {
  final VoidCallback? onRefresh;

  const ArenaChallengesSection({super.key, this.onRefresh});

  static const _maxShown = 2;

  void _openAll(BuildContext context) {
    context.pushNamed('challenges').then((_) => onRefresh?.call());
  }

  void _create(BuildContext context) {
    CustomChallengeWizard.show(context).then((_) => onRefresh?.call());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChallengesCubit, ChallengesState>(
      listenWhen: (prev, next) => next.messageId != prev.messageId,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final now = DateTime.now();
        final challenges = state.challenges ?? const <Challenge>[];
        final invites = challenges
            .where(
              (c) =>
                  c.myStatus == ParticipantStatus.invited && c.isActiveAt(now),
            )
            .toList();
        final active = challenges
            .where(
              (c) =>
                  c.myStatus == ParticipantStatus.joined && c.isActiveAt(now),
            )
            .toList();
        final open = [...invites, ...active];
        final shown = open.take(_maxShown).toList();
        final more = open.length - shown.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              'Challenges',
              // The full count when the hub leaves some out.
              count: more > 0 ? open.length : null,
              actionLabel: 'See all',
              onAction: () => _openAll(context),
            ),
            // Not loaded yet (or failed): never the "create one" empty state.
            if (state.challenges == null)
              AppCard(
                child: state.failed
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.space16,
                        ),
                        child: LoadErrorView(
                          onRetry: context.read<ChallengesCubit>().load,
                        ),
                      )
                    : const TrackerLoading(),
              )
            else if (shown.isEmpty)
              _EmptyChallenges(onCreate: () => _create(context))
            else ...[
              for (final (i, c) in shown.indexed) ...[
                if (i > 0) const SizedBox(height: AppDimens.cardGap),
                c.myStatus == ParticipantStatus.invited
                    ? _InviteRow(challenge: c, busy: state.busy.contains(c.id))
                    : ChallengeTile(
                        challenge: c,
                        busy: state.busy.contains(c.id),
                      ),
              ],
              // A labelled link, lighter than a full-width button.
              const SizedBox(height: AppDimens.space4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _create(context),
                  style: TextButton.styleFrom(
                    foregroundColor: context.vColors.accentText,
                  ),
                  icon: const Icon(Icons.add_rounded, size: AppDimens.iconMd),
                  label: const Text('New challenge'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyChallenges({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: const GameIcon(
                  GamificationIcons.quest,
                  fallback: Icons.flag_rounded,
                  size: AppDimens.iconMd,
                ),
                color: context.colors.primary,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No active challenges',
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Compete with friends on active minutes, distance or '
                      'workouts.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          AppPrimaryButton(
            label: 'New challenge',
            leadingIcon: const Icon(Icons.add_rounded, size: AppDimens.iconSm),
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

/// An open invite: what, who and time left, and Join beside it; Join
/// moves under the text when beside it the text would get narrow (large
/// text, small phones).
class _InviteRow extends StatelessWidget {
  final Challenge challenge;
  final bool busy;

  const _InviteRow({required this.challenge, required this.busy});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final grey = context.vColors.grayText;
    final join = AppPrimaryButton(
      label: 'Join',
      expand: false,
      isLoading: busy,
      onTap: () => context.read<ChallengesCubit>().respond(c, accept: true),
    );
    final text = Column(
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
          '@${c.creatorUsername} invited you · '
          '${challengeTimeLeft(c.endsAt)}',
          style: context.text.bodySmall?.copyWith(color: grey),
        ),
      ],
    );
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final beside = constraints.maxWidth >= context.textScaled(300);
          final header = Row(
            children: [
              AppIconBadge(
                icon: Icon(challengeMetricIcon(c.metric)),
                color: context.colors.primary,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(child: text),
              if (beside) ...[const SizedBox(width: AppDimens.space8), join],
            ],
          );
          if (beside) return header;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: AppDimens.space12),
              Align(alignment: AlignmentDirectional.centerEnd, child: join),
            ],
          );
        },
      ),
    );
  }
}
