import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _points = NumberFormat.decimalPattern();

/// Home card: level ring with progress to the next level, lifetime points,
/// the activity streak and today's points per category.
class ScoreStreakCard extends StatelessWidget {
  const ScoreStreakCard({super.key});

  Future<void> _push(BuildContext context, String route) async {
    final cubit = context.read<GamificationCubit>();
    await context.pushNamed(route);
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GamificationCubit, GamificationState>(
      builder: (context, state) {
        final stats = state.stats;
        if (stats == null) {
          return AppCard(
            width: double.infinity,
            child: state.failed
                ? DashboardCardError(
                    title: 'Your Score',
                    icon: Icons.emoji_events_rounded,
                    onRetry: context.read<GamificationCubit>().load,
                  )
                : const DashboardCardLoading(),
          );
        }
        return AppCard(
          width: double.infinity,
          onTap: () => _push(context, 'points-history'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardCardHeader(
                title: 'Your Score',
                icon: Icons.emoji_events_rounded,
                badgeColor: AppColors.scoreBonus,
                trailing: CardLink(
                  label: 'Badges',
                  onTap: () => _push(context, 'badges'),
                ),
              ),
              const SizedBox(height: AppDimens.cardInnerGap),
              Row(
                children: [
                  LevelRing(stats: stats),
                  const SizedBox(width: AppDimens.space16),
                  Expanded(child: _LevelSummary(stats: stats)),
                ],
              ),
              const SizedBox(height: AppDimens.cardInnerGap),
              Wrap(
                spacing: AppDimens.space8,
                runSpacing: AppDimens.space8,
                children: [
                  StreakPill(streak: stats.streak),
                  _Pill(
                    color: context.colors.primary,
                    text: '+${_points.format(state.todayTotal)} today',
                  ),
                  CardLink(
                    label: 'Your week',
                    onTap: () => _push(context, 'weekly-summary'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),
              Row(
                children: [
                  for (final c in ScoreCategory.scored) ...[
                    if (c != ScoreCategory.scored.first)
                      const SizedBox(width: AppDimens.space8),
                    Expanded(
                      child: CategoryPointsTile(
                        category: c,
                        points: state.today[c] ?? 0,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Level number inside a ring filled by progress to the next level.
class LevelRing extends StatelessWidget {
  final PlayerStats stats;
  final double size;

  const LevelRing({
    super.key,
    required this.stats,
    this.size = AppDimens.levelRing,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: stats.levelProgress,
              strokeWidth: AppDimens.levelRingStroke,
              color: color,
              backgroundColor: context.vColors.track,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LV',
                style: context.text.labelSmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
              Text(
                '${stats.level.level}',
                style: context.text.headlineSmall?.copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelSummary extends StatelessWidget {
  final PlayerStats stats;

  const _LevelSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final next = stats.nextLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardMetric('${_points.format(stats.totalPoints)} pts'),
        Text(
          stats.level.title,
          style: context.text.titleSmall?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: AppDimens.space4),
        Text(
          next == null
              ? 'Top level reached'
              : '${_points.format(stats.pointsToNextLevel)} pts to Level ${next.level}',
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}

/// "🔥 5-day streak" pill in the streak colour.
class StreakPill extends StatelessWidget {
  final int streak;

  const StreakPill({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    return _Pill(
      color: active ? AppColors.streak : context.vColors.grayText!,
      leading: GameIcon(
        GamificationIcons.streak,
        fallback: Icons.local_fire_department_rounded,
        size: AppDimens.iconXs,
        color: active ? AppColors.streak : context.vColors.grayText,
      ),
      text: active
          ? '$streak-day streak'
          : 'Earn 20 pts today to start a streak',
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final String text;
  final Widget? leading;

  const _Pill({required this.color, required this.text, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space10,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppDimens.space4),
          ],
          Flexible(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A category's colour, icon, name and points ("+12").
class CategoryPointsTile extends StatelessWidget {
  final ScoreCategory category;
  final int points;
  final bool signed;

  const CategoryPointsTile({
    super.key,
    required this.category,
    required this.points,
    this.signed = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: const EdgeInsets.all(AppDimens.space10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(category.icon, size: AppDimens.iconSm, color: color),
          const SizedBox(height: AppDimens.space6),
          Text(
            '${signed ? '+' : ''}${_points.format(points)}',
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}
