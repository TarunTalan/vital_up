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
  static const badgeStreak3 = 'assets/icons/badges/streak_3.svg';
  static const badgeStreak7 = 'assets/icons/badges/streak_7.svg';
  static const badgeStreak30 = 'assets/icons/badges/streak_30.svg';
  static const badgeStreak100 = 'assets/icons/badges/streak_100.svg';
  static const badgeSteps10k = 'assets/icons/badges/steps_10k.svg';
  static const badgeSteps20k = 'assets/icons/badges/steps_20k.svg';
  static const badgeWorkouts1 = 'assets/icons/badges/workouts_1.svg';
  static const badgeWorkouts25 = 'assets/icons/badges/workouts_25.svg';
  static const badgeWorkouts100 = 'assets/icons/badges/workouts_100.svg';
  static const badgeDiet7 = 'assets/icons/badges/diet_days_7.svg';
  static const badgeWater7 = 'assets/icons/badges/water_days_7.svg';
  static const badgeSleep7 = 'assets/icons/badges/sleep_days_7.svg';
  static const badgeCheckin14 = 'assets/icons/badges/checkin_days_14.svg';
  static const badgePoints1000 = 'assets/icons/badges/points_1000.svg';
  static const badgeLevel5 = 'assets/icons/badges/level_5.svg';
  static const badgeLevel10 = 'assets/icons/badges/level_10.svg';

  /// `badges.icon_key` → `assets/icons/badges/<key>.svg`.
  static String badge(String iconKey) => 'assets/icons/badges/$iconKey.svg';

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

/// An SVG or PNG game icon. Monochrome SVGs are tinted with [color]; rich
/// multi-color achievement badge SVGs and PNGs preserve their app theme gradients.
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
    if (asset.endsWith('.png')) {
      return Image.asset(
        asset,
        width: size,
        height: size,
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
