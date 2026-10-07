import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Visual definition and metadata for a specific game level tier.
class LevelTierConfig {
  final int level;
  final String title;
  final String tierName;
  final String tag;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color glowColor;
  final IconData icon;
  final int stars;

  const LevelTierConfig({
    required this.level,
    required this.title,
    required this.tierName,
    required this.tag,
    required this.gradientColors,
    required this.borderColor,
    required this.glowColor,
    required this.icon,
    this.stars = 1,
  });

  /// Resolves the tier configuration for a given level number.
  static LevelTierConfig forLevel(int level, {String? title}) {
    final effectiveTitle = (title != null && title.isNotEmpty)
        ? title
        : _defaultTitles[level] ?? 'Legend';

    switch (level) {
      case 1:
        return LevelTierConfig(
          level: 1,
          title: effectiveTitle,
          tierName: 'Bronze I',
          tag: 'RECRUIT',
          gradientColors: const [Color(0xFF795548), Color(0xFFA1887F), Color(0xFFD7CCC8)],
          borderColor: AppColors.rankBronze,
          glowColor: const Color(0x668D6E63),
          icon: Icons.shield_outlined,
          stars: 1,
        );
      case 2:
        return LevelTierConfig(
          level: 2,
          title: effectiveTitle,
          tierName: 'Bronze II',
          tag: 'MOVER',
          gradientColors: const [Color(0xFF8D5B4C), Color(0xFFCD7F32), Color(0xFFFFCC80)],
          borderColor: const Color(0xFFFFB74D),
          glowColor: const Color(0x66CD7F32),
          icon: Icons.directions_run_rounded,
          stars: 2,
        );
      case 3:
        return LevelTierConfig(
          level: 3,
          title: effectiveTitle,
          tierName: 'Silver I',
          tag: 'GO-GETTER',
          gradientColors: const [Color(0xFF455A64), Color(0xFF90A4AE), Color(0xFFECEFF1)],
          borderColor: AppColors.rankSilver,
          glowColor: const Color(0x6690A4AE),
          icon: Icons.bolt_rounded,
          stars: 1,
        );
      case 4:
        return LevelTierConfig(
          level: 4,
          title: effectiveTitle,
          tierName: 'Silver II',
          tag: 'ACHIEVER',
          gradientColors: const [Color(0xFF37474F), Color(0xFF78909C), Color(0xFFFFFFFF)],
          borderColor: const Color(0xFFECEFF1),
          glowColor: const Color(0x77B0BEC5),
          icon: Icons.military_tech_rounded,
          stars: 2,
        );
      case 5:
        return LevelTierConfig(
          level: 5,
          title: effectiveTitle,
          tierName: 'Gold I',
          tag: 'COMMITTED',
          gradientColors: const [Color(0xFFB78103), AppColors.rankGold, Color(0xFFFFF9C4)],
          borderColor: AppColors.rankGold,
          glowColor: const Color(0x88FFB300),
          icon: Icons.stars_rounded,
          stars: 1,
        );
      case 6:
        return LevelTierConfig(
          level: 6,
          title: effectiveTitle,
          tierName: 'Gold II',
          tag: 'CONSISTENT',
          gradientColors: const [Color(0xFFE65100), Color(0xFFFF9800), Color(0xFFFFE082)],
          borderColor: const Color(0xFFFFCA28),
          glowColor: const Color(0x99FF9800),
          icon: Icons.workspace_premium_rounded,
          stars: 2,
        );
      case 7:
        return LevelTierConfig(
          level: 7,
          title: effectiveTitle,
          tierName: 'Platinum I',
          tag: 'DEDICATED',
          gradientColors: const [Color(0xFF006064), AppColors.teal, Color(0xFFE0F7FA)],
          borderColor: AppColors.primary,
          glowColor: const Color(0x8800ACC1),
          icon: Icons.security_rounded,
          stars: 1,
        );
      case 8:
        return LevelTierConfig(
          level: 8,
          title: effectiveTitle,
          tierName: 'Platinum II',
          tag: 'STRONG',
          gradientColors: const [Color(0xFF004D40), Color(0xFF00897B), Color(0xFFB2DFDB)],
          borderColor: const Color(0xFF4DB6AC),
          glowColor: const Color(0x8800897B),
          icon: Icons.fitness_center_rounded,
          stars: 2,
        );
      case 9:
        return LevelTierConfig(
          level: 9,
          title: effectiveTitle,
          tierName: 'Emerald',
          tag: 'DRIVEN',
          gradientColors: const [Color(0xFF1B5E20), AppColors.success, Color(0xFFC8E6C9)],
          borderColor: const Color(0xFF81C784),
          glowColor: const Color(0x8843A047),
          icon: Icons.diamond_outlined,
          stars: 3,
        );
      case 10:
        return LevelTierConfig(
          level: 10,
          title: effectiveTitle,
          tierName: 'Diamond',
          tag: 'ELITE',
          gradientColors: const [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFFF3E5F5)],
          borderColor: const Color(0xFFCE93D8),
          glowColor: const Color(0x998E24AA),
          icon: Icons.diamond_rounded,
          stars: 3,
        );
      case 11:
        return LevelTierConfig(
          level: 11,
          title: effectiveTitle,
          tierName: 'Champion',
          tag: 'CHAMPION',
          gradientColors: const [Color(0xFFBF360C), AppColors.activityCalories, Color(0xFFFFCCBC)],
          borderColor: const Color(0xFFFF8A65),
          glowColor: const Color(0x99FF5722),
          icon: Icons.emoji_events_rounded,
          stars: 3,
        );
      case 12:
        return LevelTierConfig(
          level: 12,
          title: effectiveTitle,
          tierName: 'Hero',
          tag: 'HERO',
          gradientColors: const [Color(0xFF880E4F), Color(0xFFE91E63), Color(0xFFFCE4EC)],
          borderColor: const Color(0xFFF48FB1),
          glowColor: const Color(0x99E91E63),
          icon: Icons.local_fire_department_rounded,
          stars: 4,
        );
      case 13:
        return LevelTierConfig(
          level: 13,
          title: effectiveTitle,
          tierName: 'Master',
          tag: 'MASTER',
          gradientColors: const [Color(0xFF311B92), AppColors.activityWorkouts, Color(0xFFE1BEE7)],
          borderColor: const Color(0xFFBA68C8),
          glowColor: const Color(0x997B1FA2),
          icon: Icons.auto_awesome_rounded,
          stars: 4,
        );
      case 14:
        return LevelTierConfig(
          level: 14,
          title: effectiveTitle,
          tierName: 'Grandmaster',
          tag: 'GRANDMASTER',
          gradientColors: const [Color(0xFF0D47A1), Color(0xFF1E88E5), Color(0xFFBBDEFB)],
          borderColor: const Color(0xFF64B5F6),
          glowColor: const Color(0x991E88E5),
          icon: Icons.shield_moon_rounded,
          stars: 4,
        );
      case 15:
        return LevelTierConfig(
          level: 15,
          title: effectiveTitle,
          tierName: 'Legend',
          tag: 'LEGEND',
          gradientColors: const [Color(0xFFE65100), AppColors.rankGold, Color(0xFFFFF9C4)],
          borderColor: const Color(0xFFFFEE58),
          glowColor: const Color(0xAAFFB300),
          icon: Icons.whatshot_rounded,
          stars: 5,
        );
      case 16:
        return LevelTierConfig(
          level: 16,
          title: effectiveTitle,
          tierName: 'Titan',
          tag: 'TITAN',
          gradientColors: const [Color(0xFFB71C1C), Color(0xFFE64A19), Color(0xFFFFCC80)],
          borderColor: const Color(0xFFFF7043),
          glowColor: const Color(0xAAE64A19),
          icon: Icons.landslide_rounded,
          stars: 5,
        );
      case 17:
        return LevelTierConfig(
          level: 17,
          title: effectiveTitle,
          tierName: 'Mythic',
          tag: 'MYTHIC',
          gradientColors: const [Color(0xFF004D40), AppColors.primary, Color(0xFFD1C4E9)],
          borderColor: const Color(0xFF80DEEA),
          glowColor: const Color(0xAA00ACC1),
          icon: Icons.all_inclusive_rounded,
          stars: 5,
        );
      case 18:
        return LevelTierConfig(
          level: 18,
          title: effectiveTitle,
          tierName: 'Immortal',
          tag: 'IMMORTAL',
          gradientColors: const [Color(0xFF4A148C), Color(0xFFC2185B), AppColors.rankGold],
          borderColor: const Color(0xFFF06292),
          glowColor: const Color(0xAAC2185B),
          icon: Icons.flare_rounded,
          stars: 5,
        );
      case 19:
        return LevelTierConfig(
          level: 19,
          title: effectiveTitle,
          tierName: 'Icon',
          tag: 'ICON',
          gradientColors: const [Color(0xFF1A237E), Color(0xFF512DA8), Color(0xFF80D8FF)],
          borderColor: const Color(0xFFB388FF),
          glowColor: const Color(0xAA512DA8),
          icon: Icons.star_half_rounded,
          stars: 5,
        );
      default:
        // Level 20+ VitalUp Legend
        return LevelTierConfig(
          level: level,
          title: effectiveTitle,
          tierName: 'Godlike',
          tag: 'VITALUP LEGEND',
          gradientColors: const [
            Color(0xFFFF1744),
            AppColors.rankGold,
            AppColors.primary,
            Color(0xFFD500F9),
          ],
          borderColor: AppColors.white,
          glowColor: const Color(0xCC00E5FF),
          icon: Icons.workspace_premium_rounded,
          stars: 5,
        );
    }
  }

  static const Map<int, String> _defaultTitles = {
    1: 'Starter',
    2: 'Mover',
    3: 'Go-Getter',
    4: 'Achiever',
    5: 'Committed',
    6: 'Consistent',
    7: 'Dedicated',
    8: 'Strong',
    9: 'Driven',
    10: 'Elite',
    11: 'Champion',
    12: 'Hero',
    13: 'Master',
    14: 'Grandmaster',
    15: 'Legend',
    16: 'Titan',
    17: 'Mythic',
    18: 'Immortal',
    19: 'Icon',
    20: 'VitalUp Legend',
  };
}

/// A high-impact, custom-rendered gaming Level Badge.
/// Each level has unique colors, shield/crest shape, emblem icon, and glow.
class LevelBadgeWidget extends StatelessWidget {
  final int level;
  final String? title;
  final double size;
  final bool showLevelText;
  final bool showGlow;
  final VoidCallback? onTap;

  const LevelBadgeWidget({
    super.key,
    required this.level,
    this.title,
    this.size = 56.0,
    this.showLevelText = true,
    this.showGlow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = LevelTierConfig.forLevel(level, title: title);
    final badgeWidget = SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _GamerBadgePainter(
          tier: tier,
          showGlow: showGlow,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.04, bottom: size * 0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tier.icon,
                  size: size * 0.32,
                  color: AppColors.white,
                  shadows: [
                    Shadow(
                      color: AppColors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                if (showLevelText) ...[
                  SizedBox(height: size * 0.02),
                  Text(
                    '$level',
                    style: TextStyle(
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      height: 0.95,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: AppColors.black.withValues(alpha: 0.9),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                        Shadow(
                          color: tier.glowColor,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return badgeWidget;
    return GestureDetector(onTap: onTap, child: badgeWidget);
  }
}

/// Custom painter that draws a multi-faceted gaming shield emblem with
/// metallic gradient shaders, beveled edge cuts, and outer neon glow.
class _GamerBadgePainter extends CustomPainter {
  final LevelTierConfig tier;
  final bool showGlow;

  _GamerBadgePainter({
    required this.tier,
    required this.showGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer shield polygon path
    final path = Path()
      ..moveTo(w * 0.5, 0) // Top center apex
      ..lineTo(w * 0.95, h * 0.18) // Top right corner
      ..lineTo(w * 0.95, h * 0.65) // Right side
      ..lineTo(w * 0.5, h * 0.98) // Bottom shield point
      ..lineTo(w * 0.05, h * 0.65) // Left side
      ..lineTo(w * 0.05, h * 0.18) // Top left corner
      ..close();

    // 1. Outer Glow
    if (showGlow) {
      final glowPaint = Paint()
        ..color = tier.glowColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, glowPaint);
    }

    // 2. Dark Background Base (Shadow under the badge)
    final shadowPaint = Paint()
      ..color = AppColors.surfaceDark
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, shadowPaint);

    // 3. Metallic Gradient Fill
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: tier.gradientColors,
      stops: tier.gradientColors.length == 2
          ? const [0.0, 1.0]
          : tier.gradientColors.length == 3
              ? const [0.0, 0.45, 1.0]
              : const [0.0, 0.35, 0.7, 1.0],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 4. Inner Cyber Bevel (Dark contrast inner plate)
    final innerPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.88, h * 0.62)
      ..lineTo(w * 0.5, h * 0.90)
      ..lineTo(w * 0.12, h * 0.62)
      ..lineTo(w * 0.12, h * 0.22)
      ..close();

    final innerDarkPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.surfaceDarkElevated.withValues(alpha: 0.85),
          AppColors.surfaceDark.withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerDarkPaint);

    // 5. Metallic Inner Border
    final innerBorderPaint = Paint()
      ..color = tier.borderColor.withValues(alpha: 0.7)
      ..strokeWidth = math.max(AppDimens.borderThin, w * 0.02)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(innerPath, innerBorderPaint);

    // 6. Outer Beveled Border
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.white.withValues(alpha: 0.9),
          tier.borderColor,
          tier.gradientColors.first,
          tier.borderColor,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..strokeWidth = math.max(AppDimens.borderThick, w * 0.04)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    // 7. Top Gloss Highlight
    final glossPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.5, h * 0.45)
      ..lineTo(w * 0.12, h * 0.22)
      ..close();

    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.white.withValues(alpha: 0.35),
          AppColors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5))
      ..style = PaintingStyle.fill;
    canvas.drawPath(glossPath, glossPaint);

    // 8. Tier Stars at bottom
    if (tier.stars > 0) {
      final starY = h * 0.82;
      final starRadius = w * 0.04;
      final totalWidth = (tier.stars - 1) * (starRadius * 2.8);
      final startX = (w / 2) - (totalWidth / 2);

      final starPaint = Paint()
        ..color = tier.borderColor
        ..style = PaintingStyle.fill;

      for (int i = 0; i < tier.stars; i++) {
        final cx = startX + i * (starRadius * 2.8);
        canvas.drawCircle(Offset(cx, starY), starRadius, starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GamerBadgePainter oldDelegate) =>
      oldDelegate.tier.level != tier.level || oldDelegate.showGlow != showGlow;
}

/// A compact gaming pill that displays the level tag and tier name.
class LevelTagPill extends StatelessWidget {
  final int level;
  final String? title;

  const LevelTagPill({
    super.key,
    required this.level,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tier = LevelTierConfig.forLevel(level, title: title);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space10,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: tier.gradientColors.first.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: tier.borderColor.withValues(alpha: 0.6),
          width: AppDimens.borderThin,
        ),
        boxShadow: [
          BoxShadow(
            color: tier.glowColor.withValues(alpha: 0.1),
            blurRadius: AppDimens.space4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: AppDimens.iconXs - 2, color: tier.borderColor),
          const SizedBox(width: AppDimens.space4),
          Flexible(
            child: Text(
              'LVL $level • ${tier.tierName.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
