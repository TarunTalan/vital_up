import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

/// Interactive modal sheet to launch a 1v1 duel/challenge with a specific friend.
class QuickChallengeSheet extends StatefulWidget {
  final Friend friend;

  const QuickChallengeSheet({
    super.key,
    required this.friend,
  });

  static Future<bool?> show(BuildContext context, {required Friend friend}) {
    return showAppBottomSheet<bool>(
      context: context,
      builder: (ctx) => QuickChallengeSheet(friend: friend),
    );
  }

  @override
  State<QuickChallengeSheet> createState() => _QuickChallengeSheetState();
}

class _QuickChallengeSheetState extends State<QuickChallengeSheet> {
  ChallengeMetric _selectedMetric = ChallengeMetric.activeMinutes;
  int _selectedDays = 3;
  bool _submitting = false;

  Future<void> _sendChallenge() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final repo = sl<ChallengesRepository>();
      await repo.create(
        metric: _selectedMetric,
        days: _selectedDays,
        friendIds: [widget.friend.userId],
      );
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('⚔️ Challenge sent to @${widget.friend.username}!'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ChallengeException ? e.message : "Couldn't send challenge."),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final tier = LevelTierConfig.forLevel(widget.friend.level);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.gutter,
          AppDimens.space12,
          AppDimens.gutter,
          AppDimens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet drag indicator
            Center(
              child: Container(
                width: AppDimens.sheetHandleWidth,
                height: AppDimens.sheetHandleHeight,
                margin: const EdgeInsets.only(bottom: AppDimens.space16),
                decoration: BoxDecoration(
                  color: v.glassBorder,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
              ),
            ),

            // Header: 1v1 Face-off
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimens.space8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: Icon(
                    Icons.sports_martial_arts_rounded,
                    size: AppDimens.iconLg,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Challenge Friend',
                        style: context.text.titleMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '1v1 Head-to-Head Fitness Duel',
                        style: context.text.bodySmall?.copyWith(color: v.grayText),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.space16),

            // Opponent Card
            Container(
              padding: AppDimens.cardPaddingCompact,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: tier.borderColor.withValues(alpha: 0.4),
                  width: AppDimens.borderThin,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        username: widget.friend.username,
                        url: widget.friend.avatarUrl,
                        size: AppDimens.iconXxl,
                        ringColor: tier.borderColor,
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: LevelBadgeWidget(
                          level: widget.friend.level,
                          size: 20,
                          showGlow: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${widget.friend.username}',
                          style: context.text.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'LVL ${widget.friend.level} • ${tier.tierName}',
                          style: context.text.labelSmall?.copyWith(
                            color: tier.borderColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space8,
                      vertical: AppDimens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rankGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      border: Border.all(
                        color: AppColors.rankGold.withValues(alpha: 0.5),
                        width: AppDimens.borderThin,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 13,
                          color: AppColors.rankGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+50 XP Win',
                          style: context.text.labelSmall?.copyWith(
                            color: AppColors.rankGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.space16),

            // Metric Selector
            Text(
              'Select Challenge Goal',
              style: context.text.labelMedium?.copyWith(
                color: v.grayText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                _buildMetricChip(
                  metric: ChallengeMetric.activeMinutes,
                  icon: Icons.timer_rounded,
                  label: 'Active Min',
                ),
                const SizedBox(width: AppDimens.space8),
                _buildMetricChip(
                  metric: ChallengeMetric.distanceKm,
                  icon: Icons.directions_run_rounded,
                  label: 'Distance',
                ),
                const SizedBox(width: AppDimens.space8),
                _buildMetricChip(
                  metric: ChallengeMetric.workouts,
                  icon: Icons.fitness_center_rounded,
                  label: 'Workouts',
                ),
              ],
            ),

            const SizedBox(height: AppDimens.space16),

            // Duration Selector
            Text(
              'Duel Duration',
              style: context.text.labelMedium?.copyWith(
                color: v.grayText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                _buildDurationChip(days: 1, label: '24 Hours (Sprint)'),
                const SizedBox(width: AppDimens.space8),
                _buildDurationChip(days: 3, label: '3 Days (Duel)'),
                const SizedBox(width: AppDimens.space8),
                _buildDurationChip(days: 7, label: '7 Days (Battle)'),
              ],
            ),

            const SizedBox(height: AppDimens.sectionGap),

            // Action Button
            AppPrimaryButton(
              label: 'Send 1v1 Challenge',
              leadingIcon: const Icon(Icons.sports_martial_arts_rounded),
              isLoading: _submitting,
              onTap: _sendChallenge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required ChallengeMetric metric,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedMetric == metric;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMetric = metric),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.space10,
            horizontal: AppDimens.space6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : context.vColors.glassBorder!,
              width: selected ? AppDimens.borderThick : AppDimens.borderThin,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppDimens.iconMd,
                color: selected ? AppColors.primary : context.vColors.grayText,
              ),
              const SizedBox(height: AppDimens.space4),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? AppColors.white : context.vColors.grayText,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip({required int days, required String label}) {
    final selected = _selectedDays == days;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDays = days),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.space8,
            horizontal: AppDimens.space4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.rankGold.withValues(alpha: 0.15)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: selected
                  ? AppColors.rankGold
                  : context.vColors.glassBorder!,
              width: selected ? AppDimens.borderThick : AppDimens.borderThin,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: selected ? AppColors.rankGold : context.vColors.grayText,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
