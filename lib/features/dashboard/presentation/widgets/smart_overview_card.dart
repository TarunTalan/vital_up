import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_state.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_state.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

/// A smart daily overview card showing a time-aware greeting, 4 metric rings
/// (Activity, Nutrition, Water, Sleep) and a single actionable daily insight.
class SmartOverviewCard extends StatelessWidget {
  const SmartOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profState) {
        // Resolve first name from profile
        String firstName = 'Athlete';
        if (profState is ProfileLoaded) {
          final full = profState.profile.fullName.trim();
          if (full.isNotEmpty) {
            firstName = full.split(' ').first;
          } else if (profState.profile.username.isNotEmpty) {
            firstName = profState.profile.username;
          }
        } else if (profState is ProfilePhotoUpdated) {
          if (profState.profile.username.isNotEmpty) {
            firstName = profState.profile.username;
          }
        }

        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';

        return BlocBuilder<WaterIntakeCubit, WaterIntakeState>(
          builder: (context, waterState) {
            double? waterFrac;
            if (waterState is WaterIntakeLoaded && waterState.dailyGoalMl > 0) {
              waterFrac =
                  (waterState.currentIntakeMl / waterState.dailyGoalMl)
                      .clamp(0.0, 1.0);
            }

            return BlocBuilder<SleepCubit, SleepState>(
              builder: (context, sleepState) {
                double? sleepFrac;
                if (sleepState is SleepLoadedAuto) {
                  sleepFrac =
                      (sleepState.session.duration.inMinutes / 480.0)
                          .clamp(0.0, 1.0);
                } else if (sleepState is SleepLoadedManual) {
                  sleepFrac =
                      (sleepState.session.duration.inMinutes / 480.0)
                          .clamp(0.0, 1.0);
                }

                return BlocBuilder<MealLogBloc, MealLogState>(
                  builder: (context, nutritionState) {
                    double? nutrFrac;
                    if (nutritionState is MealLogLoaded) {
                      final goal =
                          (nutritionState.dailyCalorieGoal ?? 2000).toDouble();
                      if (goal > 0) {
                        nutrFrac =
                            (nutritionState.totalCalories / goal)
                                .clamp(0.0, 1.0);
                      }
                    }

                    return BlocBuilder<ActivityGoalsCubit, ActivityGoalsState>(
                      builder: (context, actState) {
                        double? actFrac;
                        if (actState.goals.isNotEmpty) {
                          actFrac = actState.goals.first.fraction;
                        }

                        final insight = _buildInsight(
                          hour: hour,
                          waterFrac: waterFrac,
                          sleepFrac: sleepFrac,
                          nutrFrac: nutrFrac,
                          actFrac: actFrac,
                        );

                        return BlocBuilder<GamificationCubit, GamificationState>(
                          builder: (context, gameState) {
                            final stats = gameState.stats;
                            return AppCard(
                              padding: const EdgeInsets.all(AppDimens.space20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── Greeting + insight ──
                                  Text(
                                    '$greeting, $firstName!',
                                    style: context.text.titleMedium?.copyWith(
                                      color: context.colors.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppDimens.space4),
                                  Text(
                                    insight,
                                    style: context.text.bodySmall?.copyWith(
                                      color: context.vColors.grayText,
                                    ),
                                  ),
                                  // ── Gamification row ──
                                  if (stats != null) ...[
                                    const SizedBox(height: AppDimens.space16),
                                    _GamificationRow(stats: stats),
                                  ],
                                  const SizedBox(height: AppDimens.space20),
                                  // ── Today's metric rings ──
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _MiniRing(
                                        metric: TrackerMetric.activity,
                                        fraction: actFrac,
                                      ),
                                      _MiniRing(
                                        metric: TrackerMetric.nutrition,
                                        fraction: nutrFrac,
                                      ),
                                      _MiniRing(
                                        metric: TrackerMetric.water,
                                        fraction: waterFrac,
                                      ),
                                      _MiniRing(
                                        metric: TrackerMetric.sleep,
                                        fraction: sleepFrac,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _buildInsight({
    required int hour,
    double? waterFrac,
    double? sleepFrac,
    double? nutrFrac,
    double? actFrac,
  }) {
    if (hour < 12 && (waterFrac ?? 0) < 0.1) {
      return 'Start your day with a glass of water.';
    }
    if ((sleepFrac ?? 1) < 0.6 && hour < 11) {
      return 'Rough night? Take it easy and rest up tonight.';
    }
    if ((actFrac ?? 0) < 0.5 && hour > 14) {
      return "A quick walk could push you past your activity goal.";
    }
    if ((waterFrac ?? 0) >= 1.0) {
      return "Hydration goal crushed today! 💧";
    }
    if ((nutrFrac ?? 0) >= 1.0) {
      return "You've hit your calorie goal for today. Great job!";
    }
    if ((actFrac ?? 0) >= 1.0) {
      return "All activity goals done! You're on fire 🔥";
    }
    return "Keep it up — you're making great progress today!";
  }
}

/// A compact ring + label for a single metric.
class _MiniRing extends StatelessWidget {
  final TrackerMetric metric;
  final double? fraction;

  const _MiniRing({required this.metric, this.fraction});

  String get _shortLabel => switch (metric) {
        TrackerMetric.screenTime => 'Screen',
        TrackerMetric.mood => 'Mood',
        _ => metric.label.split(' ').first,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrackerRing(
          size: 54,
          fraction: fraction,
          color: metric.color,
          center: SvgPicture.asset(
            metric.iconAsset,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(metric.color, BlendMode.srcIn),
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        Text(
          _shortLabel,
          style: context.text.labelSmall?.copyWith(
            color: context.vColors.grayText,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Level badge + XP progress bar + streak pill in a single row.
class _GamificationRow extends StatelessWidget {
  final PlayerStats stats;
  const _GamificationRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tier = LevelTierConfig.forLevel(
      stats.level.level,
      title: stats.level.title,
    );
    final xpFrac = stats.levelProgress;
    final toNext = stats.pointsToNextLevel;
    final streak = stats.streak;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space10,
      ),
      decoration: BoxDecoration(
        color: tier.borderColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: tier.borderColor.withValues(alpha: 0.25),
          width: AppDimens.borderThin,
        ),
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: tier.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              '${stats.level.level}',
              style: context.text.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          // XP bar + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      stats.level.title,
                      style: context.text.labelMedium?.copyWith(
                        color: tier.borderColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      toNext > 0
                          ? '${stats.totalPoints} XP  ·  $toNext to next'
                          : '${stats.totalPoints} XP  ·  Max level!',
                      style: context.text.labelSmall?.copyWith(
                        color: context.vColors.grayText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.space6),
                AppProgressBar(
                  value: xpFrac,
                  color: tier.borderColor,
                  trackColor: tier.borderColor.withValues(alpha: 0.18),
                  height: 5,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          // Streak pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.space8,
              vertical: AppDimens.space4,
            ),
            decoration: BoxDecoration(
              color: AppColors.streak.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: AppColors.streak,
                ),
                const SizedBox(width: 3),
                Text(
                  '$streak',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.streak,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
