import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

/// An interactive gaming badge card that flips 180° around the Y-axis with a
/// 3D perspective animation upon clicking, revealing the badge's goal and
/// progress on the reverse side.
class FlipBadgeCard extends StatefulWidget {
  final GameBadge badge;
  final double? width;
  final double? height;
  final double badgeSize;
  final bool showFlipHint;
  final VoidCallback? onFlipped;

  const FlipBadgeCard({
    super.key,
    required this.badge,
    this.width,
    this.height,
    this.badgeSize = 52.0,
    this.showFlipHint = true,
    this.onFlipped,
  });

  @override
  State<FlipBadgeCard> createState() => _FlipBadgeCardState();
}

class _FlipBadgeCardState extends State<FlipBadgeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isFront = true;

  static final _number = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.selectionClick();
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
    widget.onFlipped?.call();
  }

  String? get _progressLabel {
    final badge = widget.badge;
    if (badge.progressFraction == null || badge.threshold == null) return null;
    final t = badge.threshold!;
    final p = (badge.progress ?? 0).clamp(0, t);
    return '${_number.format(p)} of ${_number.format(t)}';
  }

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        final angle = val * math.pi;
        final isBack = val >= 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isBack
              ? Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildBack(context),
                )
              : _buildFront(context),
        );
      },
    );

    if (widget.width != null || widget.height != null) {
      card = SizedBox(
        width: widget.width,
        height: widget.height,
        child: card,
      );
    }

    return GestureDetector(
      onTap: _flip,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  /// Front of the card: The visual emblem, name, status, and progress.
  Widget _buildFront(BuildContext context) {
    final badge = widget.badge;
    final isEarned = badge.earned;
    final progressLabel = _progressLabel;
    final fraction = badge.progressFraction;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isEarned
        ? AppColors.rankGold.withValues(alpha: 0.45)
        : context.colors.outlineVariant.withValues(alpha: 0.25);

    final bgGradient = isEarned
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E2230),
                    const Color(0xFF262015),
                  ]
                : [
                    AppColors.white,
                    const Color(0xFFFFFDF5),
                  ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF171A21),
                    const Color(0xFF12141A),
                  ]
                : [
                    AppColors.white,
                    const Color(0xFFF8FAFC),
                  ],
          );

    return Container(
      padding: const EdgeInsets.all(AppDimens.space10),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: borderColor, width: isEarned ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: (isEarned ? AppColors.rankGold : AppColors.primary)
                .withValues(alpha: isEarned ? 0.14 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row: Status pill & Bonus XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? AppColors.rankGold.withValues(alpha: 0.16)
                          : context.vColors.grayText!.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(
                        color: isEarned
                            ? AppColors.rankGold.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEarned
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                          size: 10,
                          color: isEarned
                              ? AppColors.rankGold
                              : context.vColors.grayText,
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          isEarned ? 'EARNED' : 'LOCKED',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: isEarned
                                ? AppColors.rankGold
                                : context.vColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (badge.bonusPoints > 0) ...[
                const SizedBox(width: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rankGold.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 10,
                          color: AppColors.rankGold,
                        ),
                        Text(
                          '+${badge.bonusPoints}',
                          style: const TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            color: AppColors.rankGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Center: Large Badge Icon + Main Title strictly in Single Line
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isEarned ? 1.0 : AppDimens.badgeLockedOpacity,
                  child: GameIcon(
                    GamificationIcons.badge(badge.iconKey),
                    fallback: isEarned
                        ? Icons.military_tech_rounded
                        : Icons.lock_outline_rounded,
                    size: widget.badgeSize,
                  ),
                ),
                const SizedBox(height: AppDimens.space8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      badge.name,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.colors.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom section: Progress or Flip Hint
          if (!isEarned && fraction != null && progressLabel != null) ...[
            AppProgressBar(
              value: fraction,
              color: context.colors.primary,
              height: AppDimens.badgeProgressHeight,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                progressLabel,
                maxLines: 1,
                style: context.text.labelSmall?.copyWith(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: context.vColors.grayText,
                ),
              ),
            ),
          ] else if (widget.showFlipHint) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3.5,
              ),
              decoration: BoxDecoration(
                color: (isEarned ? AppColors.rankGold : context.colors.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                border: Border.all(
                  color: (isEarned ? AppColors.rankGold : context.colors.primary)
                      .withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 11,
                      color: isEarned
                          ? AppColors.rankGold
                          : context.colors.primary,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'Tap for goal',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isEarned
                            ? AppColors.rankGold
                            : context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Back of the card: Reveals the Goal to achieve this badge with full,
  /// non-truncated text and single-line card title.
  Widget _buildBack(BuildContext context) {
    final badge = widget.badge;
    final isEarned = badge.earned;
    final progressLabel = _progressLabel;
    final fraction = badge.progressFraction;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = isEarned ? AppColors.rankGold : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1B2232),
                  const Color(0xFF11141C),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFEDF2F7),
                ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Goal Tag + Flip Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      size: 10.0,
                      color: accentColor,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'GOAL',
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.flip_rounded,
                size: 14,
                color: accentColor.withValues(alpha: 0.85),
              ),
            ],
          ),

          // Center: Main Title in single line + Complete description without ellipsis
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        badge.name,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          badge.description.isNotEmpty
                              ? badge.description
                              : 'Complete this achievement to unlock the badge.',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: Progress or Completion status + reward
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEarned) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rankGold.withValues(alpha: 0.16),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(
                        color: AppColors.rankGold.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 11,
                          color: AppColors.rankGold,
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          badge.earnedAt != null
                              ? DateFormat.yMMMd().format(badge.earnedAt!.toLocal())
                              : 'Achieved!',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.rankGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (fraction != null && progressLabel != null) ...[
                AppProgressBar(
                  value: fraction,
                  color: AppColors.primary,
                  height: AppDimens.badgeProgressHeight,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Progress: $progressLabel',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ] else if (badge.threshold != null) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Target: ${badge.threshold}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Tap to flip back',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: context.vColors.grayText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens a high-impact dialog showcasing the badge in large format with
/// full 3D flip card interaction.
void showBadgeGoalDialog(BuildContext context, GameBadge badge) {
  HapticFeedback.mediumImpact();
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space24,
        vertical: AppDimens.space32,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 250,
              height: 340,
              child: FlipBadgeCard(
                badge: badge,
                badgeSize: 108.0,
                showFlipHint: true,
              ),
            ),
            const SizedBox(height: AppDimens.space16),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: Container(
                padding: const EdgeInsets.all(AppDimens.space8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
