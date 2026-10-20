import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

final _points = NumberFormat.decimalPattern();

/// Arena hero: level ring, level title and points to the next level, then
/// streak, today's points and banked rest days. Tap for points history.
/// Shortcuts to badges, points and the activity calendar sit below it.
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
                    title: 'Your level',
                    icon: Icons.emoji_events_rounded,
                    onRetry: context.read<GamificationCubit>().load,
                  )
                : const DashboardCardLoading(),
          );
        }
        final next = stats.nextLevel;
        final v = context.vColors;
        String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              width: double.infinity,
              onTap: () => _push(context, 'points-history'),
              showChevron: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      LevelRing(stats: stats),
                      const SizedBox(width: AppDimens.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level ${stats.level.level}',
                              style: context.text.labelLarge?.copyWith(
                                color: v.accentText,
                              ),
                            ),
                            Text(
                              stats.level.title,
                              style: context.text.titleLarge?.copyWith(
                                color: context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppDimens.space4),
                            Text(
                              next == null
                                  ? '${_points.format(stats.totalPoints)} pts'
                                        ' · top level'
                                  : '${_points.format(stats.totalPoints)} pts'
                                        ' · ${_points.format(stats.pointsToNextLevel)}'
                                        ' to Level ${next.level}',
                              style: context.text.bodySmall?.copyWith(
                                color: v.grayText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space16),
                  Divider(height: AppDimens.borderThin, color: v.divider),
                  const SizedBox(height: AppDimens.space12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Stat(
                            icon: Icons.local_fire_department_rounded,
                            iconAsset: GamificationIcons.streakFlame,
                            color: stats.streak > 0
                                ? AppColors.streak
                                : v.grayText!,
                            value: days(stats.streak),
                            label: 'Streak',
                          ),
                        ),
                        VerticalDivider(
                          width: AppDimens.space16,
                          color: v.divider,
                        ),
                        Expanded(
                          child: _Stat(
                            icon: Icons.star_rounded,
                            iconAsset: GamificationIcons.points,
                            color: context.colors.primary,
                            value: '+${_points.format(state.todayTotal)}',
                            label: 'Today',
                          ),
                        ),
                        VerticalDivider(
                          width: AppDimens.space16,
                          color: v.divider,
                        ),
                        Expanded(
                          child: _Stat(
                            icon: Icons.ac_unit_rounded,
                            color: stats.streakFreezes > 0
                                ? AppColors.info
                                : v.grayText!,
                            value: '${stats.streakFreezes}',
                            label: stats.streakFreezes == 1
                                ? 'Rest day'
                                : 'Rest days',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.cardGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.military_tech_rounded,
                      label: 'Badges',
                      onTap: () => _push(context, 'badges'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.cardGap),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.insights_rounded,
                      label: 'Points',
                      onTap: () => _push(context, 'points-history'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.cardGap),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.calendar_month_rounded,
                      label: 'Calendar',
                      onTap: () => _push(context, 'activity-calendar'),
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

/// One figure under the level: icon, value and a short label, centred.
class _Stat extends StatelessWidget {
  final IconData icon;
  final String? iconAsset;
  final Color color;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          iconAsset != null
              ? GameIcon(
                  iconAsset!,
                  fallback: icon,
                  size: AppDimens.iconMd,
                  color: color,
                )
              : Icon(icon, size: AppDimens.iconMd, color: color),
          const SizedBox(height: AppDimens.space4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square-ish shortcut card: icon over a one-word label.
class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space8,
          vertical: AppDimens.space12,
        ),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimens.iconLg,
              color: context.vColors.accentText,
            ),
            const SizedBox(height: AppDimens.space6),
            // One word: shrinks to fit rather than breaking mid-word.
            FitText(
              label,
              textAlign: TextAlign.center,
              style: context.text.labelLarge?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
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
          GameIcon(
            GamificationIcons.levelHexagon(stats.level.level),
            fallback: Icons.shield_rounded,
            size: size * 0.48,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// "5-day streak" pill in the streak colour.
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
                color: context.colors.onSurface,
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
          category.iconAsset != null
              ? GameIcon(
                  category.iconAsset!,
                  fallback: category.icon,
                  size: AppDimens.iconSm,
                  color: context.iconTint(color),
                )
              : Icon(
                  category.icon,
                  size: AppDimens.iconSm,
                  color: context.iconTint(color),
                ),
          const SizedBox(height: AppDimens.space6),
          // Narrow tiles (4 across on small phones): the total shrinks to
          // fit instead of breaking mid-number, and the label wraps.
          FitText(
            '${signed ? '+' : ''}${_points.format(points)}',
            maxLines: 1,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          Text(
            category.label,
            maxLines: 2,
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
