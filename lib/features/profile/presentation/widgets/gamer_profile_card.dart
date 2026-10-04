import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

final _numberFormat = NumberFormat.decimalPattern();

/// A feature-rich, high-impact gaming status card for the user's profile.
/// Displays level, XP progression, level badge, global rank, streaks, and
/// category point stats using app-wide design tokens and gaming aesthetics.
class GamerProfileCard extends StatefulWidget {
  final VoidCallback? onRefresh;
  final bool compact;

  const GamerProfileCard({
    super.key,
    this.onRefresh,
    this.compact = false,
  });

  const GamerProfileCard.compact({
    super.key,
    this.onRefresh,
  }) : compact = true;

  @override
  State<GamerProfileCard> createState() => _GamerProfileCardState();
}

class _GamerProfileCardState extends State<GamerProfileCard> {
  LeaderboardEntry? _myRankEntry;
  Community? _globalCommunity;

  @override
  void initState() {
    super.initState();
    _fetchGlobalRank();
  }

  Future<void> _fetchGlobalRank() async {
    if (!mounted) return;
    try {
      final repo = sl<CommunityRepository>();
      final communities = await repo.getCommunities();
      final global = communities.where((c) => c.type == CommunityType.global).firstOrNull;
      if (global != null) {
        final rank = await repo.getMyRank(global, period: LeaderboardPeriod.all);
        if (mounted) {
          setState(() {
            _globalCommunity = global;
            _myRankEntry = rank;
          });
        }
      }
    } catch (_) {
      // Graceful offline fallback: keep cached or null rank
    }
  }

  void _openLeaderboard(BuildContext context) {
    if (_globalCommunity != null) {
      context.pushNamed(
        'leaderboard',
        pathParameters: {'id': _globalCommunity!.id},
        extra: _globalCommunity,
      );
    } else {
      sl<CommunityRepository>().getCommunities().then((list) {
        final global = list.where((c) => c.type == CommunityType.global).firstOrNull;
        if (global != null && context.mounted) {
          context.pushNamed(
            'leaderboard',
            pathParameters: {'id': global.id},
            extra: global,
          );
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return BlocBuilder<GamificationCubit, GamificationState>(
      builder: (context, gameState) {
        final stats = gameState.stats ?? PlayerStats.empty;
        final currentLevel = stats.level.level;
        final levelTitle = stats.level.title;
        final tier = LevelTierConfig.forLevel(currentLevel, title: levelTitle);
        final progress = stats.levelProgress;
        final totalPoints = stats.totalPoints;
        final nextLevel = stats.nextLevel;
        final pointsToNext = stats.pointsToNextLevel;

        final rank = _myRankEntry?.rank;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppDimens.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            color: v.glassFill,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceDarkElevated.withValues(alpha: 0.95),
                AppColors.surfaceDark,
                tier.gradientColors.first.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: tier.borderColor.withValues(alpha: 0.35),
              width: AppDimens.borderThin + 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tier.glowColor.withValues(alpha: 0.25),
                blurRadius: AppDimens.space20,
                offset: const Offset(0, 6),
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: AppDimens.space16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            child: Stack(
              children: [
                // 1. Ambient Glow Accents
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tier.glowColor.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          context.colors.primary.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Card Content
                Padding(
                  padding: AppDimens.cardPaddingCompact,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Level Badge, Title, Rank Pill, Total Points
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'profile_level_badge_${tier.level}',
                            child: LevelBadgeWidget(
                              level: currentLevel,
                              title: levelTitle,
                              size: 60,
                              showGlow: true,
                              onTap: () => context.pushNamed('points-history'),
                            ),
                          ),
                          const SizedBox(width: AppDimens.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppDimens.space6,
                                  runSpacing: AppDimens.space2,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppDimens.space8,
                                        vertical: AppDimens.space2 + 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tier.borderColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppDimens.radiusXs),
                                        border: Border.all(
                                          color: tier.borderColor.withValues(alpha: 0.6),
                                          width: AppDimens.borderThin,
                                        ),
                                      ),
                                      child: Text(
                                        'LEVEL $currentLevel',
                                        style: context.text.labelSmall?.copyWith(
                                          color: tier.borderColor,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      levelTitle.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.titleSmall?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppDimens.space4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppDimens.space4,
                                  runSpacing: AppDimens.space2,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _openLeaderboard(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppDimens.space6,
                                          vertical: AppDimens.space2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: rank != null && rank <= 3
                                              ? AppColors.rankGold.withValues(alpha: 0.2)
                                              : AppColors.surfaceDarkElevated,
                                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                          border: Border.all(
                                            color: rank != null && rank <= 3
                                                ? AppColors.rankGold.withValues(alpha: 0.7)
                                                : context.colors.primary.withValues(alpha: 0.4),
                                            width: AppDimens.borderThin,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              rank != null && rank <= 3
                                                  ? Icons.emoji_events_rounded
                                                  : Icons.leaderboard_rounded,
                                              size: AppDimens.iconXs - 3,
                                              color: rank != null && rank <= 3
                                                  ? AppColors.rankGold
                                                  : context.colors.primary,
                                            ),
                                            const SizedBox(width: AppDimens.space4),
                                            Text(
                                              rank != null ? '#$rank' : 'Unranked',
                                              style: context.text.labelSmall?.copyWith(
                                                color: rank != null && rank <= 3
                                                    ? AppColors.rankGold
                                                    : AppColors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '• ${tier.tierName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall?.copyWith(
                                        color: v.grayText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _numberFormat.format(totalPoints),
                                style: context.text.titleLarge?.copyWith(
                                  color: tier.borderColor,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: tier.glowColor.withValues(alpha: 0.8),
                                      blurRadius: AppDimens.space8,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'TOTAL XP',
                                style: context.text.labelSmall?.copyWith(
                                  color: v.grayText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.5,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimens.space12),

                      // 3. Level XP Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'XP PROGRESS',
                                style: context.text.labelSmall?.copyWith(
                                  color: v.grayText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: AppDimens.space8),
                              Flexible(
                                child: Text(
                                  nextLevel == null
                                      ? 'MAX LEVEL'
                                      : '${_numberFormat.format(pointsToNext)} XP to Lv ${nextLevel.level}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: context.text.bodySmall?.copyWith(
                                    color: tier.borderColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.space6),
                          Container(
                            height: AppDimens.progressHeight + 2,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                              border: Border.all(
                                color: v.glassBorder!,
                                width: AppDimens.borderThin,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: progress.clamp(0.02, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            context.colors.primary,
                                            tier.borderColor,
                                            AppColors.white,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: tier.glowColor,
                                            blurRadius: AppDimens.space8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _CyberProgressBarPainter(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimens.space12),

                      // 4. Gamer Quick Stats Row (Rank, Level, Streak, Badges)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.space10,
                          horizontal: AppDimens.space8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          border: Border.all(
                            color: v.glassBorder!,
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _GamerStatItem(
                                icon: Icons.emoji_events_rounded,
                                iconColor: rank != null && rank <= 3
                                    ? AppColors.rankGold
                                    : context.colors.primary,
                                value: rank != null ? '#$rank' : '–',
                                label: 'RANK',
                                onTap: () => _openLeaderboard(context),
                              ),
                            ),
                            _buildStatDivider(v.glassBorder!),
                            Expanded(
                              child: _GamerStatItem(
                                icon: Icons.shield_rounded,
                                iconColor: tier.borderColor,
                                value: 'Lv. $currentLevel',
                                label: 'LEVEL',
                                onTap: () => context.pushNamed('points-history'),
                              ),
                            ),
                            _buildStatDivider(v.glassBorder!),
                            Expanded(
                              child: _GamerStatItem(
                                icon: Icons.local_fire_department_rounded,
                                iconColor: AppColors.streak,
                                value: '${stats.streak}d',
                                label: 'STREAK',
                                onTap: () => context.pushNamed('weekly-summary'),
                              ),
                            ),
                            _buildStatDivider(v.glassBorder!),
                            Expanded(
                              child: _GamerStatItem(
                                icon: Icons.military_tech_rounded,
                                iconColor: AppColors.rankGold,
                                value: 'Vault',
                                label: 'BADGES',
                                onTap: () => context.pushNamed('badges'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (widget.compact) ...[
                        const SizedBox(height: AppDimens.space8),
                        InkWell(
                          onTap: () => context.pushNamed('profile'),
                          borderRadius: BorderRadius.circular(AppDimens.radiusXs),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppDimens.space2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View Complete Profile & Categories',
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: AppDimens.space4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: AppDimens.iconXs - 2,
                                  color: context.colors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (!widget.compact) ...[
                        const SizedBox(height: AppDimens.space12),

                        // 5. Category XP Pills Row (Nutrition, Fitness, Lifestyle, Bonus)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final c in ScoreCategory.scored) ...[
                                _CategoryXpChip(
                                  category: c,
                                  points: stats.pointsIn(c),
                                ),
                                const SizedBox(width: AppDimens.space8),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.space12),

                        // 6. Action Shortcuts: Leaderboard, Badges, Points History
                        Row(
                          children: [
                            Expanded(
                              child: _GamerActionButton(
                                icon: Icons.leaderboard_rounded,
                                label: 'Leaderboard',
                                color: context.colors.primary,
                                onTap: () => _openLeaderboard(context),
                              ),
                            ),
                            const SizedBox(width: AppDimens.space8),
                            Expanded(
                              child: _GamerActionButton(
                                icon: Icons.military_tech_rounded,
                                label: 'Badges',
                                color: AppColors.rankGold,
                                onTap: () => context.pushNamed('badges'),
                              ),
                            ),
                            const SizedBox(width: AppDimens.space8),
                            Expanded(
                              child: _GamerActionButton(
                                icon: Icons.history_rounded,
                                label: 'XP History',
                                color: tier.borderColor,
                                onTap: () => context.pushNamed('points-history'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatDivider(Color borderColor) {
    return Container(
      width: AppDimens.borderThin,
      height: AppDimens.space24,
      color: borderColor,
    );
  }
}

class _GamerStatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _GamerStatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: AppDimens.iconXs - 2, color: iconColor),
                const SizedBox(width: AppDimens.space4),
                Flexible(
                  child: Text(
                    value,
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
            const SizedBox(height: AppDimens.space2),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: context.vColors.grayText,
                fontWeight: FontWeight.w700,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryXpChip extends StatelessWidget {
  final ScoreCategory category;
  final int points;

  const _CategoryXpChip({
    required this.category,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space10,
        vertical: AppDimens.space6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: AppDimens.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          category.iconAsset != null
              ? GameIcon(
                  category.iconAsset!,
                  fallback: category.icon,
                  size: AppDimens.iconXs - 3,
                  color: color,
                )
              : Icon(category.icon, size: AppDimens.iconXs - 3, color: color),
          const SizedBox(width: AppDimens.space4),
          Text(
            category.label,
            style: context.text.labelSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppDimens.space4),
          Text(
            '+${_numberFormat.format(points)}',
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GamerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GamerActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.space8,
            horizontal: AppDimens.space6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: AppDimens.borderThin,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppDimens.iconXs - 2, color: color),
              const SizedBox(width: AppDimens.space4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for cyber slant lines on the progress bar.
class _CyberProgressBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.18)
      ..strokeWidth = AppDimens.borderThin + 0.5;

    for (double x = -10; x < size.width + 10; x += AppDimens.space8) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + AppDimens.space6, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
