import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/adaptive_row.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/user_avatar.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/pages/head_to_head_comparison_page.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/presentation/widgets/badge_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/gamification/presentation/widgets/score_streak_card.dart';

final _number = NumberFormat.decimalPattern();

/// A member's profile, opened from leaderboards, champions, friends and
/// your own row ("how others see you"). Top to bottom:
///
/// - who: avatar, name, @username, level;
/// - what you can do: Add friend / Accept / Request sent, or for friends
///   Challenge, Cheer and Compare (Remove friend sits in the menu);
/// - one stats card: points, streak, badges;
/// - Awards (best award and counts, the full list a tap away), Recent
///   badges and, for friends, Points by area.
///
/// Members hidden from leaderboards show their level only.
class PlayerProfilePage extends StatefulWidget {
  final String? userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final int level;

  /// After a friend was removed here (the opener refreshes its list).
  final VoidCallback? onFriendRemoved;

  const PlayerProfilePage({
    super.key,
    required this.userId,
    required this.username,
    required this.level,
    this.fullName,
    this.avatarUrl,
    this.onFriendRemoved,
  });

  static Future<void> open(
    BuildContext context, {
    required String? userId,
    required String username,
    required int level,
    String? fullName,
    String? avatarUrl,
    VoidCallback? onFriendRemoved,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<FriendsCubit>(
          create: (_) => sl<FriendsCubit>()..load(),
          child: PlayerProfilePage(
            userId: userId,
            username: username,
            level: level,
            fullName: fullName,
            avatarUrl: avatarUrl,
            onFriendRemoved: onFriendRemoved,
          ),
        ),
      ),
    );
  }

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  final _repo = sl<CommunityRepository>();
  late Future<PlayerProfile?> _profile = _loadProfile();
  late Future<List<CommunityAward>> _awards = _loadAwards();
  bool _cheered = false;
  bool _cheering = false;

  bool get _isSelf {
    final uid = widget.userId;
    return uid != null &&
        sl.isRegistered<SupabaseClient>() &&
        uid == sl<SupabaseClient>().auth.currentUser?.id;
  }

  Future<PlayerProfile?> _loadProfile() async {
    final uid = widget.userId;
    if (uid == null) return null;
    final p = await _repo.getPlayerProfile(uid);
    if (mounted) setState(() => _cheered = p.cheeredToday);
    return p;
  }

  /// Optional: no awards section when they can't load.
  Future<List<CommunityAward>> _loadAwards() async {
    final uid = widget.userId;
    if (uid == null) return const [];
    try {
      return await _repo.getPlayerAwards(uid);
    } catch (e) {
      debugPrint('Awards failed to load: $e');
      return const [];
    }
  }

  Future<void> _reload() async {
    setState(() {
      _profile = _loadProfile();
      _awards = _loadAwards();
    });
    await Future.wait([
      _profile.then((_) {}, onError: (_) {}),
      _awards,
      context.read<FriendsCubit>().load(),
    ]);
  }

  Friend? _friendOf(FriendsState state) {
    final uid = widget.userId;
    final name = widget.username.toLowerCase();
    return state.friends
        ?.where(
          (f) =>
              uid != null ? f.userId == uid : f.username.toLowerCase() == name,
        )
        .firstOrNull;
  }

  Future<void> _cheer(Friend friend) async {
    if (_cheering || _cheered) return;
    setState(() => _cheering = true);
    try {
      await _repo.sendCheer(friend.userId);
      if (!mounted) return;
      setState(() => _cheered = true);
      showSuccessSnackBar(context, 'Cheer sent to @${friend.username}');
    } on PlayerProfileException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
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

  Future<void> _openMenu(Friend friend) async {
    final remove = await showAppBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        top: false,
        child: ListTile(
          leading: Icon(Icons.person_remove_rounded, color: sheet.colors.error),
          title: Text(
            'Remove friend',
            style: TextStyle(color: sheet.colors.error),
          ),
          onTap: () => Navigator.of(sheet).pop(true),
        ),
      ),
    );
    if (remove != true || !mounted) return;
    final errorColor = context.colors.error;
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove @${friend.username}?'),
        content: const Text(
          "You'll no longer see each other on your friends board.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<FriendsCubit>().remove(friend);
    widget.onFriendRemoved?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsCubit, FriendsState>(
      builder: (context, friends) {
        final friend = _friendOf(friends);
        final accepted = friend?.status == FriendStatus.accepted;
        return AppScaffold(
          header: AppPageHeader(
            title: 'Profile',
            action: accepted && !_isSelf
                ? AppHeaderAction(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded),
                    onTap: () => _openMenu(friend!),
                  )
                : null,
          ),
          onRefresh: _reload,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Identity(
                username: widget.username,
                fullName: widget.fullName ?? friend?.fullName,
                avatarUrl: widget.avatarUrl ?? friend?.avatarUrl,
                level: widget.level,
              ),
              const SizedBox(height: AppDimens.space16),
              if (_isSelf)
                const AppInfoNote(
                  message:
                      'This is how other members see you. Points by area '
                      'show to friends only.',
                  icon: Icons.visibility_outlined,
                )
              else
                _Actions(
                  username: widget.username,
                  friend: friend,
                  friends: friends,
                  cheered: _cheered,
                  cheering: _cheering,
                  onCheer: _cheer,
                ),
              FutureBuilder<PlayerProfile?>(
                future: _profile,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppDimens.sectionGap),
                      child: LoadErrorView(onRetry: _reload),
                    );
                  }
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(AppDimens.space32),
                      child: Center(child: VitalUpLoader()),
                    );
                  }
                  final profile = snap.data;
                  if (profile == null) return const SizedBox.shrink();
                  if (profile.isPrivate) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppDimens.sectionGap),
                      child: AppInfoNote(
                        message:
                            '@${widget.username} keeps their stats private. '
                            'Their level still shows.',
                        icon: Icons.lock_outline_rounded,
                      ),
                    );
                  }
                  return _Sections(
                    profile: profile,
                    awards: _awards,
                    username: widget.username,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Avatar, name, @username and level, centred.
class _Identity extends StatelessWidget {
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final int level;

  const _Identity({
    required this.username,
    required this.level,
    this.fullName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final name = fullName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final grey = context.vColors.grayText;
    return Column(
      children: [
        Container(
          width: AppDimens.avatarLarge,
          height: AppDimens.avatarLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.colors.primary,
              width: AppDimens.borderThick + 0.5,
            ),
          ),
          child: ClipOval(
            child: UserAvatar(
              username: username,
              url: avatarUrl,
              size: AppDimens.avatarLarge,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.space12),
        Text(
          hasName ? name : '@$username',
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
        if (hasName) ...[
          const SizedBox(height: AppDimens.space2),
          Text(
            '@$username',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: grey),
          ),
        ],
        const SizedBox(height: AppDimens.space8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(
              GamificationIcons.levelHexagon(level),
              fallback: Icons.shield_rounded,
              size: AppDimens.iconSm,
              color: context.colors.primary,
            ),
            const SizedBox(width: AppDimens.space6),
            Flexible(
              child: Text(
                'Level $level · ${levelTitle(level)}',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The friendship's next step: Add friend / Accept / Request sent, or a
/// friend's Challenge, Cheer and Compare. Nothing while friends load.
class _Actions extends StatelessWidget {
  final String username;
  final Friend? friend;
  final FriendsState friends;
  final bool cheered;
  final bool cheering;
  final void Function(Friend friend) onCheer;

  const _Actions({
    required this.username,
    required this.friend,
    required this.friends,
    required this.cheered,
    required this.cheering,
    required this.onCheer,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.friends == null) return const SizedBox.shrink();
    final f = friend;
    final cubit = context.read<FriendsCubit>();
    if (f != null && f.status == FriendStatus.accepted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPrimaryButton(
            label: 'Challenge',
            leadingIcon: const Icon(Icons.flag_rounded, size: AppDimens.iconSm),
            onTap: () => QuickChallengeSheet.show(context, friend: f),
          ),
          const SizedBox(height: AppDimens.buttonGap),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: cheered ? 'Cheered' : 'Cheer',
                  leadingIcon: Icon(
                    cheered ? Icons.check_rounded : Icons.thumb_up_alt_rounded,
                    size: AppDimens.iconSm,
                  ),
                  enabled: !cheered,
                  isLoading: cheering,
                  onTap: () => onCheer(f),
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HeadToHeadComparisonPage(friend: f),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (f != null && f.status == FriendStatus.incoming) {
      return Row(
        children: [
          Expanded(
            child: AppPrimaryButton(
              label: 'Accept',
              leadingIcon: const Icon(
                Icons.check_rounded,
                size: AppDimens.iconSm,
              ),
              onTap: () => cubit.respond(f, accept: true),
            ),
          ),
          const SizedBox(width: AppDimens.buttonGap),
          Expanded(
            child: AppSecondaryButton(
              label: 'Decline',
              onTap: () => cubit.respond(f, accept: false),
            ),
          ),
        ],
      );
    }
    if (f != null && f.status == FriendStatus.outgoing) {
      return AppSecondaryButton(
        label: 'Request sent',
        leadingIcon: const Icon(
          Icons.hourglass_empty_rounded,
          size: AppDimens.iconSm,
        ),
        enabled: false,
        onTap: () {},
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPrimaryButton(
          label: 'Add friend',
          leadingIcon: const Icon(
            Icons.person_add_rounded,
            size: AppDimens.iconSm,
          ),
          isLoading: friends.sending,
          onTap: () => cubit.send(username),
        ),
        const SizedBox(height: AppDimens.space8),
        Text(
          'Friends can cheer, compare and challenge each other.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}

/// Stats, awards, recent badges and (friends) points by area.
class _Sections extends StatelessWidget {
  final PlayerProfile profile;
  final Future<List<CommunityAward>> awards;
  final String username;

  const _Sections({
    required this.profile,
    required this.awards,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimens.sectionGap),
        AppCard(
          width: double.infinity,
          padding: AppDimens.cardPaddingCompact,
          child: TrackerFigureRow(
            figures: [
              TrackerFigure(
                label: 'Points',
                value: _number.format(p.totalPoints),
                iconAsset: GamificationIcons.points,
                icon: Icons.star_rounded,
                color: AppColors.scoreBonus,
              ),
              TrackerFigure(
                label: 'Streak',
                value: days(p.currentStreak),
                iconAsset: GamificationIcons.streakFlame,
                icon: Icons.local_fire_department_rounded,
                color: AppColors.streak,
              ),
              TrackerFigure(
                label: 'Badges',
                value: _number.format(p.badgeCount),
                iconAsset: GamificationIcons.badgeIcon,
                icon: Icons.military_tech_rounded,
                color: AppColors.rankGold,
              ),
            ],
          ),
        ),
        FutureBuilder<List<CommunityAward>>(
          future: awards,
          builder: (context, snap) {
            final list = snap.data;
            if (list == null || list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.sectionGap),
                AppSectionHeader('Awards', count: list.length),
                AwardsSummaryCard(
                  awards: list,
                  onSeeAll: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PlayerAwardsPage(username: username, awards: list),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (p.recentBadges.isNotEmpty) ...[
          const SizedBox(height: AppDimens.sectionGap),
          const AppSectionHeader('Recent badges'),
          Wrap(
            spacing: AppDimens.space12,
            runSpacing: AppDimens.space12,
            children: [
              for (final b in p.recentBadges)
                Tooltip(
                  message: b.name,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => showBadgeDetailSheet(context, b),
                    child: BadgeEmblem(
                      badge: b,
                      size: AppDimens.iconBadgeLarge,
                    ),
                  ),
                ),
            ],
          ),
        ],
        // Points by area: the caller and friends only (Compare's data).
        if (p.isFriend) ...[
          const SizedBox(height: AppDimens.sectionGap),
          const AppSectionHeader('Points by area'),
          AdaptiveRow(
            children: [
              for (final c in ScoreCategory.scored)
                CategoryPointsTile(
                  category: c,
                  points: p.pointsIn(c),
                  signed: false,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
