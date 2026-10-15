import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/pages/head_to_head_comparison_page.dart';
import 'package:vital_up/features/community/presentation/widgets/common_communities_section.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/community/presentation/widgets/player_inspect_sheet.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

final _number = NumberFormat.decimalPattern();

/// A community member preview sheet, matching the friends profile preview
/// with circular avatar, tier badges, stats overview and friendship actions.
class PublicProfileSheet extends StatefulWidget {
  final String username;
  final int level;
  final String? avatarUrl;
  final String? userId;
  final int? points;
  final int? rank;
  final int? streak;
  final String? activeSince;

  const PublicProfileSheet({
    super.key,
    required this.username,
    required this.level,
    this.avatarUrl,
    this.userId,
    this.points,
    this.rank,
    this.streak,
    this.activeSince,
  });

  static Future<void> show(
    BuildContext context, {
    required String username,
    required int level,
    String? avatarUrl,
    String? userId,
    int? points,
    int? rank,
    int? streak,
    String? activeSince,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (_) => BlocProvider<FriendsCubit>(
        create: (_) => sl<FriendsCubit>()..load(),
        child: PublicProfileSheet(
          username: username,
          level: level,
          avatarUrl: avatarUrl,
          userId: userId,
          points: points,
          rank: rank,
          streak: streak,
          activeSince: activeSince,
        ),
      ),
    );
  }

  @override
  State<PublicProfileSheet> createState() => _PublicProfileSheetState();
}

class _PublicProfileSheetState extends State<PublicProfileSheet> {
  final _repo = sl<CommunityRepository>();
  late final Future<PlayerProfile?> _profile = _load();
  bool _cheered = false;
  bool _cheering = false;

  Future<PlayerProfile?> _load() async {
    final uid = widget.userId;
    if (uid == null) return null;
    try {
      final p = await _repo.getPlayerProfile(uid);
      if (mounted) setState(() => _cheered = p.cheeredToday);
      return p;
    } catch (_) {
      // User is not yet a friend or has private stats
      return null;
    }
  }

  Future<void> _cheer(String userId) async {
    if (_cheering || _cheered) return;
    setState(() => _cheering = true);
    try {
      await _repo.sendCheer(userId);
      if (!mounted) return;
      setState(() => _cheered = true);
      showSuccessSnackBar(context, 'Cheer sent to @${widget.username}');
    } catch (e) {
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

  void _closeThen(void Function(BuildContext host) next) {
    final navigator = Navigator.of(context);
    navigator.pop();
    next(navigator.context);
  }

  String get _activePeriodLabel {
    final active = widget.activeSince;
    if (active != null && active.trim().isNotEmpty) {
      final trimmed = active.trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('active') || lower.startsWith('member')) {
        return trimmed;
      }
      return 'Active since $trimmed';
    }
    final streak = widget.streak;
    if (streak != null && streak > 0) {
      return 'Active for $streak consecutive days';
    }
    return 'Active member this season';
  }

  @override
  Widget build(BuildContext context) {
    final tier = LevelTierConfig.forLevel(widget.level);
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
            // Circular Avatar with level tier border (no glow)
            Center(
              child: Container(
                width: AppDimens.avatarLarge,
                height: AppDimens.avatarLarge,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tier.borderColor,
                    width: AppDimens.borderThick + 0.5,
                  ),
                ),
                child: ClipOval(
                  child: UserAvatar(
                    username: widget.username,
                    url: widget.avatarUrl,
                    size: AppDimens.avatarLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space16),

            // Centered Username
            Text(
              '@${widget.username}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.space4),

            // Level & Tier Subtitle Row (Single clean display, no duplicate capsule)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameIcon(
                  GamificationIcons.levelHexagon(widget.level),
                  fallback: Icons.shield_rounded,
                  size: AppDimens.iconSm,
                  color: context.colors.primary,
                ),
                const SizedBox(width: AppDimens.space6),
                Text(
                  'Level ${widget.level} · ${tier.tierName}',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space6),

            // Active Period / Member Since Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: AppDimens.iconXs,
                  color: grey,
                ),
                const SizedBox(width: AppDimens.space4),
                Text(
                  _activePeriodLabel,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(color: grey),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sectionGap),

            // Stats Section: Full stats if friend / public, or gamer summary card
            FutureBuilder<PlayerProfile?>(
              future: _profile,
              builder: (context, snap) {
                final profile = snap.data;
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimens.space24),
                    child: Center(child: VitalUpLoader()),
                  );
                }

                if (profile != null && !profile.isPrivate) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PlayerProfileStats(profile: profile),
                      if (widget.userId != null)
                        CommonCommunitiesSection(
                          friendUserId: widget.userId!,
                          friendUsername: widget.username,
                        ),
                    ],
                  );
                }

                // If not friends or profile stats private, show leaderboard / overview card
                final streakVal = widget.streak ?? profile?.currentStreak ?? 0;
                final bestVal = profile?.longestStreak ?? 0;
                final activityText = widget.activeSince != null
                    ? widget.activeSince!
                    : (streakVal > 0
                        ? '$streakVal d streak'
                        : (bestVal > 0 ? '${bestVal}d best' : 'Active member'));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      width: double.infinity,
                      padding: AppDimens.cardPaddingCompact,
                      child: TrackerFigureRow(
                        figures: [
                          TrackerFigure(
                            label: 'Points',
                            value: _number.format(
                              widget.points ?? profile?.totalPoints ?? 0,
                            ),
                            iconAsset: GamificationIcons.points,
                            icon: Icons.star_rounded,
                            color: AppColors.scoreBonus,
                          ),
                          TrackerFigure(
                            label: widget.rank != null ? 'Rank' : 'Tier',
                            value: widget.rank != null
                                ? '#${widget.rank}'
                                : tier.tierName,
                            iconAsset: (widget.rank != null && widget.rank! <= 3)
                                ? GamificationIcons.leaderboardRank(
                                    widget.rank!,
                                  )
                                : (widget.rank == null
                                    ? GamificationIcons.levelHexagon(
                                        widget.level,
                                      )
                                    : null),
                            icon: Icons.military_tech_rounded,
                            color: (widget.rank == 1)
                                ? AppColors.rankGold
                                : context.colors.primary,
                          ),
                          TrackerFigure(
                            label: 'Activity',
                            value: activityText,
                            iconAsset: GamificationIcons.streakFlame,
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.streak,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.space12),
                    const AppInfoNote(
                      message:
                          'Connect as friends to compare progress, send '
                          'cheers and start challenges together.',
                      icon: Icons.people_outline_rounded,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),

            // Friendship Actions
            BlocBuilder<FriendsCubit, FriendsState>(
              builder: (context, state) {
                final friend = state.friends
                    ?.where(
                      (f) =>
                          f.username.toLowerCase() ==
                          widget.username.toLowerCase(),
                    )
                    .firstOrNull;

                if (friend != null && friend.status == FriendStatus.accepted) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPrimaryButton(
                        label: 'Challenge',
                        leadingIcon: const Icon(
                          Icons.flag_rounded,
                          size: AppDimens.iconSm,
                        ),
                        onTap: () => _closeThen(
                          (host) =>
                              QuickChallengeSheet.show(host, friend: friend),
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
                                    : Icons.thumb_up_alt_rounded,
                                size: AppDimens.iconSm,
                              ),
                              enabled: !_cheered,
                              isLoading: _cheering,
                              onTap: () => _cheer(friend.userId),
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
                                    builder: (_) => HeadToHeadComparisonPage(
                                      friend: friend,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else if (friend != null &&
                    friend.status == FriendStatus.incoming) {
                  return Row(
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Accept Request',
                          leadingIcon: const Icon(
                            Icons.check_rounded,
                            size: AppDimens.iconSm,
                          ),
                          onTap: () => context.read<FriendsCubit>().respond(
                            friend,
                            accept: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.buttonGap),
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Decline',
                          onTap: () => context.read<FriendsCubit>().respond(
                            friend,
                            accept: false,
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (friend != null &&
                    friend.status == FriendStatus.outgoing) {
                  return AppSecondaryButton(
                    label: 'Request Sent',
                    leadingIcon: const Icon(
                      Icons.hourglass_empty_rounded,
                      size: AppDimens.iconSm,
                    ),
                    enabled: false,
                    onTap: () {},
                  );
                }

                return AppPrimaryButton(
                  label: 'Add Friend',
                  leadingIcon: const Icon(
                    Icons.person_add_rounded,
                    size: AppDimens.iconSm,
                  ),
                  isLoading: state.sending,
                  onTap: () {
                    context.read<FriendsCubit>().send(widget.username);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
