import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/pages/head_to_head_comparison_page.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';
import 'package:vital_up/features/gamification/presentation/widgets/score_streak_card.dart';

final _number = NumberFormat.decimalPattern();

String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

/// A friend's profile: level, points, streaks and recent badges from the
/// server, with Challenge, Cheer, Compare and (when [onRemove] is given)
/// Remove friend.
class PlayerInspectSheet extends StatefulWidget {
  final Friend friend;
  final VoidCallback? onRemove;

  const PlayerInspectSheet({super.key, required this.friend, this.onRemove});

  static Future<void> show(
    BuildContext context, {
    required Friend friend,
    VoidCallback? onRemove,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (_) => PlayerInspectSheet(friend: friend, onRemove: onRemove),
    );
  }

  @override
  State<PlayerInspectSheet> createState() => _PlayerInspectSheetState();
}

class _PlayerInspectSheetState extends State<PlayerInspectSheet> {
  final _repo = sl<CommunityRepository>();
  late Future<PlayerProfile> _profile = _load();
  bool _cheered = false;
  bool _cheering = false;

  Future<PlayerProfile> _load() =>
      _repo.getPlayerProfile(widget.friend.userId).then((p) {
        if (mounted) setState(() => _cheered = p.cheeredToday);
        return p;
      });

  Future<void> _cheer() async {
    if (_cheering || _cheered) return;
    setState(() => _cheering = true);
    try {
      await _repo.sendCheer(widget.friend.userId);
      if (!mounted) return;
      setState(() => _cheered = true);
      showSuccessSnackBar(context, 'Cheer sent to @${widget.friend.username}');
    } on PlayerProfileException catch (e) {
      if (!mounted) return;
      // Sent earlier (maybe from another device): show it as sent.
      if (e.message == PlayerProfileException.alreadyCheered) {
        setState(() => _cheered = true);
      }
      showErrorSnackBar(context, e.message);
    } catch (e) {
      debugPrint('Cheer failed: $e');
      if (mounted) {
        showErrorSnackBar(
          context,
          userMessage(e, fallback: "Couldn't send the cheer. Try again."),
        );
      }
    } finally {
      if (mounted) setState(() => _cheering = false);
    }
  }

  /// This sheet's context dies on pop, so the next screen opens from the
  /// navigator's.
  void _closeThen(void Function(BuildContext host) next) {
    final navigator = Navigator.of(context);
    navigator.pop();
    next(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final name = friend.fullName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final tier = LevelTierConfig.forLevel(friend.level);
    final grey = context.vColors.grayText;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space12,
          context.gutter,
          AppDimens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                username: friend.username,
                url: friend.avatarUrl,
                size: AppDimens.avatarLarge,
              ),
            ),
            const SizedBox(height: AppDimens.space16),
            Text(
              hasName ? name : '@${friend.username}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.space4),
            Text(
              [
                if (hasName) '@${friend.username}',
                'Level ${friend.level}',
                tier.tierName,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: grey),
            ),
            const SizedBox(height: AppDimens.sectionGap),
            FutureBuilder<PlayerProfile>(
              future: _profile,
              builder: (context, snap) {
                if (snap.hasError) {
                  final error = snap.error;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (error is PlayerProfileException)
                        AppInfoNote(message: error.message),
                      LoadErrorView(
                        onRetry: () => setState(() {
                          _profile = _load();
                        }),
                      ),
                    ],
                  );
                }
                final profile = snap.data;
                if (profile == null) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimens.space24),
                    child: Center(child: VitalUpLoader()),
                  );
                }
                if (profile.isPrivate) {
                  return AppInfoNote(
                    message: '@${friend.username} keeps their stats private.',
                    icon: Icons.lock_outline_rounded,
                  );
                }
                return _ProfileStats(profile: profile);
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Challenge',
              leadingIcon: const Icon(
                Icons.flag_rounded,
                size: AppDimens.iconSm,
              ),
              onTap: () => _closeThen(
                (host) => QuickChallengeSheet.show(host, friend: friend),
              ),
            ),
            const SizedBox(height: AppDimens.buttonGap),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: _cheered ? 'Cheered today' : 'Cheer',
                    leadingIcon: Icon(
                      _cheered
                          ? Icons.check_rounded
                          : Icons.thumb_up_alt_outlined,
                      size: AppDimens.iconSm,
                    ),
                    enabled: !_cheered,
                    isLoading: _cheering,
                    onTap: _cheer,
                  ),
                ),
                const SizedBox(width: AppDimens.buttonGap),
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Compare',
                    leadingIcon: const Icon(
                      Icons.compare_arrows_rounded,
                      size: AppDimens.iconSm,
                    ),
                    onTap: () => _closeThen(
                      (host) => Navigator.of(host).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HeadToHeadComparisonPage(friend: friend),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.onRemove != null) ...[
              const SizedBox(height: AppDimens.space8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
                icon: const Icon(
                  Icons.person_remove_outlined,
                  size: AppDimens.iconSm,
                ),
                label: const Text('Remove friend'),
                onPressed: () => _closeThen((_) => widget.onRemove!()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Points, streaks, points per category and recent badges.
class _ProfileStats extends StatelessWidget {
  final PlayerProfile profile;

  const _ProfileStats({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          width: double.infinity,
          padding: AppDimens.cardPaddingCompact,
          child: Column(
            children: [
              TrackerFigureRow(
                figures: [
                  TrackerFigure(
                    label: 'Total points',
                    value: _number.format(p.totalPoints),
                    icon: Icons.star_rounded,
                    color: AppColors.scoreBonus,
                  ),
                  TrackerFigure(
                    label: 'Badges',
                    value: _number.format(p.badgeCount),
                    icon: Icons.military_tech_rounded,
                    color: AppColors.rankGold,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),
              TrackerFigureRow(
                figures: [
                  TrackerFigure(
                    label: 'Current streak',
                    value: _days(p.currentStreak),
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.streak,
                  ),
                  TrackerFigure(
                    label: 'Best streak',
                    value: _days(p.longestStreak),
                    icon: Icons.emoji_events_outlined,
                    color: AppColors.streak,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.cardGap),
        Row(
          children: [
            for (final c in ScoreCategory.scored) ...[
              if (c != ScoreCategory.scored.first)
                const SizedBox(width: AppDimens.space8),
              Expanded(
                child: CategoryPointsTile(
                  category: c,
                  points: p.pointsIn(c),
                  signed: false,
                ),
              ),
            ],
          ],
        ),
        if (p.recentBadges.isNotEmpty) ...[
          const SizedBox(height: AppDimens.space16),
          const AppSectionHeader('Recent badges'),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              for (final b in p.recentBadges)
                Tooltip(
                  message: b.name,
                  child: AppIconBadge(
                    color: AppColors.rankGold,
                    size: AppDimens.iconBadgeLarge,
                    icon: GameIcon(
                      GamificationIcons.badge(b.iconKey),
                      fallback: Icons.military_tech_rounded,
                      size: AppDimens.iconLg,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
