import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/challenges/presentation/widgets/custom_challenge_wizard.dart';

/// Arena section: open invites first, then up to [_maxActive] running
/// challenges and a way to start a new one, then the latest
/// [_maxHistory] finished or left ones. "See all" opens the full list.
class ArenaChallengesSection extends StatelessWidget {
  final VoidCallback? onRefresh;

  const ArenaChallengesSection({super.key, this.onRefresh});

  static const _maxActive = 3;
  static const _maxHistory = 3;

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
            .take(_maxActive)
            .toList();
        final shown = [...invites, ...active];
        final history = challenges
            .where((c) => !challengeIsOpen(c, now))
            .take(_maxHistory)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              'Challenges',
              actionLabel: 'See all',
              onAction: () => _openAll(context),
            ),
            if (shown.isEmpty)
              _EmptyChallenges(onCreate: () => _create(context))
            else ...[
              for (final c in shown) ...[
                ChallengeTile(challenge: c, busy: state.busy.contains(c.id)),
                const SizedBox(height: AppDimens.cardGap),
              ],
              AppSecondaryButton(
                label: 'New challenge',
                leadingIcon: const Icon(
                  Icons.add_rounded,
                  size: AppDimens.iconSm,
                ),
                onTap: () => _create(context),
              ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: AppDimens.sectionGap),
              AppSectionHeader(
                'Challenge history',
                actionLabel: 'See all',
                onAction: () => _openAll(context),
              ),
              for (final c in history) ...[
                ChallengeTile(challenge: c),
                if (c != history.last)
                  const SizedBox(height: AppDimens.cardGap),
              ],
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
                icon: const Icon(Icons.flag_rounded),
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
