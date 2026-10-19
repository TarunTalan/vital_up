import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Asset paths for gamification icons. These SVGs are supplied by design;
/// until a file exists, [GameIcon] falls back to a Material icon.
abstract final class GamificationIcons {
  static const community = 'assets/icons/nav/community.svg';
  static const trophy = 'assets/icons/gamification/trophy.svg';
  static const streak = 'assets/icons/gamification/streak_flame.svg';
  static const crown = 'assets/icons/gamification/crown.svg';

  // Player levels & progression
  static const level = 'assets/icons/gamification/level.svg';
  static const levelUp = 'assets/icons/gamification/level_up.svg';
  static const rankStar = 'assets/icons/gamification/rank_star.svg';
  static const gameCrown = 'assets/icons/gamification/crown.svg';

  // Badges & Achievements
  static const badgeIcon = 'assets/icons/gamification/badge.svg';
  static const achievement = 'assets/icons/gamification/achievement.svg';
  static const medal = 'assets/icons/gamification/medal.svg';
  static const gameTrophy = 'assets/icons/gamification/trophy.svg';
  static const milestone = 'assets/icons/gamification/milestone.svg';

  // Rewards & Prizes
  static const reward = 'assets/icons/gamification/reward.svg';
  static const rewardChest = 'assets/icons/gamification/reward_chest.svg';
  static const prize = 'assets/icons/gamification/prize.svg';

  // Points & Currency
  static const points = 'assets/icons/gamification/points.svg';
  static const coins = 'assets/icons/gamification/coins.svg';
  static const energy = 'assets/icons/gamification/energy.svg';

  // Bonus & Streaks
  static const bonus = 'assets/icons/gamification/bonus.svg';
  static const bonusMultiplier =
      'assets/icons/gamification/bonus_multiplier.svg';
  static const streakFlame = 'assets/icons/gamification/streak_flame.svg';
  static const shield = 'assets/icons/gamification/shield.svg';
  static const target = 'assets/icons/gamification/target.svg';
  static const celebration = 'assets/icons/gamification/celebration.svg';
  static const gaming = 'assets/icons/gamification/gaming.svg';
  static const quest = 'assets/icons/gamification/quest.svg';

  // VitalUp Achievement Badges
  static const badgeStreak3 = 'assets/images/badges/streak_3.webp';
  static const badgeStreak7 = 'assets/images/badges/streak_7.webp';
  static const badgeStreak30 = 'assets/images/badges/streak_30.webp';
  static const badgeStreak100 = 'assets/images/badges/streak_100.webp';
  static const badgeSteps10k = 'assets/images/badges/steps_10k.webp';
  static const badgeSteps20k = 'assets/images/badges/steps_20k.webp';
  static const badgeWorkouts1 = 'assets/images/badges/workouts_1.webp';
  static const badgeWorkouts25 = 'assets/images/badges/workouts_25.webp';
  static const badgeWorkouts100 = 'assets/images/badges/workouts_100.webp';
  static const badgeDiet7 = 'assets/images/badges/diet_days_7.webp';
  static const badgeWater7 = 'assets/images/badges/water_days_7.webp';
  static const badgeSleep7 = 'assets/images/badges/sleep_days_7.webp';
  static const badgeCheckin14 = 'assets/images/badges/checkin_days_14.webp';
  static const badgePoints1000 = 'assets/images/badges/points_1000.webp';
  static const badgeLevel5 = 'assets/images/badges/level_5.webp';
  static const badgeLevel10 = 'assets/images/badges/level_10.webp';

  /// `badges.icon_key` → `assets/images/badges/<key>.webp`. The badges are
  /// raster art: WebP decodes far faster than the source SVGs (which only
  /// wrap an embedded PNG) and is less than half their size.
  static String badge(String iconKey) => 'assets/images/badges/$iconKey.webp';

  /// Top 1..3 leaderboard rank laurel wreath SVGs.
  static String? leaderboardRank(int rank) {
    if (rank >= 1 && rank <= 3) {
      return 'assets/icons/leaderboard_ranks/laurel-wreath-$rank.svg';
    }
    return null;
  }

  /// Hexagonal level number SVG (0..9). There are no two-digit hexagons, so
  /// levels 10+ use the plain level icon rather than a misleading digit.
  static String levelHexagon(int level) {
    if (level < 0 || level > 9) return GamificationIcons.level;
    return 'assets/icons/levels/hexagon-number-$level.svg';
  }

  /// `communities.icon_key` → `assets/icons/communities/<key>.svg`.
  static String communityIcon(String iconKey) {
    final key = iconKey.toLowerCase();
    if (key == 'weight-loss' || key == 'weight' || key.contains('weight')) {
      return 'assets/icons/trackers/weight_icon.svg';
    }
    if (key == 'step' ||
        key == 'steps' ||
        key.contains('step') ||
        key.contains('walk')) {
      return 'assets/icons/trackers/step.svg';
    }
    if (key == 'activity' ||
        key.contains('activity') ||
        key.contains('workout') ||
        key == 'runners' ||
        key == 'joggers') {
      return 'assets/icons/trackers/activity.svg';
    }
    return 'assets/icons/communities/$iconKey.svg';
  }
}

/// An SVG, PNG or WebP game icon. Monochrome SVGs are tinted with [color];
/// badge and award art keeps its own colours.
class GameIcon extends StatelessWidget {
  final String asset;
  final IconData fallback;
  final double size;
  final Color? color;

  const GameIcon(
    this.asset, {
    super.key,
    required this.fallback,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    if (asset.endsWith('.png') || asset.endsWith('.webp')) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        // Decode at the shown size, not the source resolution.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(fallback, size: size, color: tint),
      );
    }
    final multiColour =
        asset.contains('/badges/') || asset.contains('/awards/');
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: multiColour || tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn),
      errorBuilder: (_, _, _) => Icon(fallback, size: size, color: tint),
    );
  }
}
