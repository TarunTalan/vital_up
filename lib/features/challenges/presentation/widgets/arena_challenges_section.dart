import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';

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
  if (left.inHours >= 1) return '${left.inHours}h left';
  return 'Ends soon';
}

/// An engaging challenges section designed for the Gamification Arena hub.
/// Displays high-priority incoming invites with Accept/Decline and XP stakes,
/// active challenges with live progress, and a quick-action to start a 1v1 duel.
class ArenaChallengesSection extends StatelessWidget {
  final VoidCallback? onRefresh;

  const ArenaChallengesSection({
    super.key,
    this.onRefresh,
  });

  void _openChallengesPage(BuildContext context) {
    context.pushNamed('challenges').then((_) => onRefresh?.call());
  }

  void _createNewChallenge(BuildContext context) {
    context.pushNamed('challenges').then((_) => onRefresh?.call());
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final now = DateTime.now();

    return BlocBuilder<ChallengesCubit, ChallengesState>(
      builder: (context, state) {
        final cubit = context.read<ChallengesCubit>();
        final challenges = state.challenges ?? [];

        final incoming = challenges
            .where((c) => c.myStatus == ParticipantStatus.invited && c.isActiveAt(now))
            .toList();

        final active = challenges
            .where((c) => c.myStatus == ParticipantStatus.joined && c.isActiveAt(now))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Challenges',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (incoming.isNotEmpty) ...[
                      const SizedBox(width: AppDimens.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.streak.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                          border: Border.all(
                            color: AppColors.streak.withValues(alpha: 0.6),
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: Text(
                          '${incoming.length} ACTION',
                          style: context.text.labelSmall?.copyWith(
                            color: AppColors.streak,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    // New Challenge button
                    InkWell(
                      onTap: () => _createNewChallenge(context),
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space10,
                          vertical: AppDimens.space4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                          border: Border.all(
                            color: context.colors.primary.withValues(alpha: 0.4),
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: AppDimens.iconXs,
                              color: context.colors.primary,
                            ),
                            const SizedBox(width: AppDimens.space4),
                            Text(
                              'New',
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.space8),
                    // See all
                    InkWell(
                      onTap: () => _openChallengesPage(context),
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space4,
                          vertical: AppDimens.space4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'See All',
                              style: context.text.bodySmall?.copyWith(
                                color: v.grayText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: v.grayText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space12),

            // 1. Incoming Challenges (Needs Action)
            for (final c in incoming) ...[
              _IncomingChallengeCard(
                challenge: c,
                busy: state.busy.contains(c.id),
                onAccept: () => cubit.respond(c, accept: true),
                onDecline: () => cubit.respond(c, accept: false),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],

            // 2. Active Challenges (In Progress)
            for (final c in active) ...[
              _ActiveChallengeCard(
                challenge: c,
                onTap: () => _openChallengesPage(context),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],

            // 3. If no active & no incoming, show quick challenge card
            if (incoming.isEmpty && active.isEmpty)
              AppCard(
                width: double.infinity,
                padding: AppDimens.cardPaddingCompact,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimens.space12),
                      decoration: BoxDecoration(
                        color: AppColors.rankGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.rankGold.withValues(alpha: 0.5),
                          width: AppDimens.borderThin,
                        ),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: AppDimens.iconLg,
                        color: AppColors.rankGold,
                      ),
                    ),
                    const SizedBox(width: AppDimens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active challenges',
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            'Start a 1v1 duel with a friend. Winner wins +50 XP bonus!',
                            style: context.text.bodySmall?.copyWith(
                              color: v.grayText,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space8),
                          AppPrimaryButton(
                            label: '⚔️ Challenge a Friend',
                            expand: false,
                            onTap: () => _createNewChallenge(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _IncomingChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingChallengeCard({
    required this.challenge,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final c = challenge;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.streak.withValues(alpha: 0.12),
            AppColors.surfaceDark,
            context.colors.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: AppColors.streak.withValues(alpha: 0.6),
          width: AppDimens.borderThin + 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.streak.withValues(alpha: 0.15),
            blurRadius: AppDimens.space16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: AppDimens.cardPaddingCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimens.space8),
                  decoration: BoxDecoration(
                    color: AppColors.streak.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.streak.withValues(alpha: 0.6),
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_kabaddi_rounded,
                    size: AppDimens.iconMd,
                    color: AppColors.streak,
                  ),
                ),
                const SizedBox(width: AppDimens.space10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '⚔️ Duel Invite from @${c.creatorUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.metric.label} · ${_timeLeft(c.endsAt)}',
                        style: context.text.bodySmall?.copyWith(
                          color: v.grayText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space10),

            // Stakes Row (Winner / Loser)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space10,
                vertical: AppDimens.space6,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: v.glassBorder!,
                  width: AppDimens.borderThin,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: AppDimens.iconXs,
                        color: AppColors.rankGold,
                      ),
                      const SizedBox(width: AppDimens.space4),
                      Text(
                        'Winner: +50 XP',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.rankGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 14,
                    color: v.glassBorder,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_down_rounded,
                        size: AppDimens.iconXs,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppDimens.space4),
                      Text(
                        'Loser: -25 XP',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space12),

            // Action Buttons (Decline / Accept)
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Decline',
                    isLoading: busy,
                    onTap: onDecline,
                  ),
                ),
                const SizedBox(width: AppDimens.space10),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Accept & Fight',
                    isLoading: busy,
                    onTap: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;

  const _ActiveChallengeCard({
    required this.challenge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final c = challenge;

    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                color: context.colors.primary,
                icon: Icon(
                  _metricIcon(c.metric),
                  size: AppDimens.iconSm,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.space10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.metric.label,
                      style: context.text.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'vs @${c.creatorUsername} · ${_timeLeft(c.endsAt)}',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(
                    color: context.colors.primary.withValues(alpha: 0.4),
                    width: AppDimens.borderThin,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.military_tech_rounded,
                      size: AppDimens.iconXs - 2,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      c.myRank != null ? '#${c.myRank}' : 'Active',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space10),

          // Score & Stakes row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Score: ${c.metric.format(c.myScore ?? 0)}',
                style: context.text.bodySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Stakes: ±50 XP',
                style: context.text.labelSmall?.copyWith(
                  color: AppColors.rankGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
