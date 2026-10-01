import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Asset paths for gamification icons. These SVGs are supplied by design;
/// until a file exists, [GameIcon] falls back to a Material icon.
abstract final class GamificationIcons {
  static const community = 'assets/icons/community.svg';
  static const trophy = 'assets/icons/trophy.svg';
  static const streak = 'assets/icons/streak.svg';
  static const crown = 'assets/icons/crown.svg';

  /// `badges.icon_key` → `assets/icons/badges/<key>.svg`.
  static String badge(String iconKey) => 'assets/icons/badges/$iconKey.svg';

  /// `communities.icon_key` → `assets/icons/communities/<key>.svg`.
  static String communityIcon(String iconKey) =>
      'assets/icons/communities/$iconKey.svg';
}

/// An SVG icon tinted with [color], or [fallback] when the asset is missing.
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
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn),
      errorBuilder: (_, _, _) => Icon(fallback, size: size, color: tint),
    );
  }
}
