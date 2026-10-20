import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/user_avatar.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/invite_share_card.dart';
import 'package:vital_up/features/community/presentation/widgets/player_inspect_sheet.dart';
import 'package:vital_up/features/community/presentation/widgets/public_profile_sheet.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/core/widgets/name_with_you_tag.dart';

final _points = NumberFormat.decimalPattern();

/// Friends, Requests and Sent tabs: the friends ranking (with the caller in
/// it), requests to answer and requests waiting on others, with search on
/// long lists. Adding a friend and inviting live in one sheet behind the
/// header button.
class FriendsPage extends StatelessWidget {
  /// The caller's own username, shown so they can share it.
  final String? myUsername;

  const FriendsPage({super.key, this.myUsername});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FriendsCubit>()..load(),
      child: _FriendsView(myUsername: myUsername),
    );
  }
}

enum _Tab { friends, requests, sent }

class _FriendsView extends StatefulWidget {
  final String? myUsername;

  const _FriendsView({this.myUsername});

  @override
  State<_FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<_FriendsView> {
  /// Null until the user picks a tab: opens on Requests while some wait.
  _Tab? _picked;
  final _search = TextEditingController();
  String _query = '';

  /// Search appears once a list is long enough to need it.
  static const _searchFrom = 6;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  _Tab _tab(FriendsState state) =>
      _picked ?? (state.incoming.isNotEmpty ? _Tab.requests : _Tab.friends);

  void _openAddSheet() {
    final cubit = context.read<FriendsCubit>();
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _AddFriendSheet(myUsername: widget.myUsername),
      ),
    );
  }

  Future<void> _confirmRemove(Friend friend) async {
    final cubit = context.read<FriendsCubit>();
    final errorColor = context.colors.error;
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove @${friend.username}?'),
        content: const Text(
          "You'll no longer see each other on your friends board.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.remove(friend);
  }

  void _showProfile(Friend f) => PublicProfileSheet.show(
    context,
    username: f.username,
    level: f.level,
    avatarUrl: f.avatarUrl,
    userId: f.userId,
  );

  bool _matches(String username, String? name) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return username.toLowerCase().contains(q) ||
        (name?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FriendsCubit, FriendsState>(
      // The add sheet shows its own errors; skip them here while it's open.
      listenWhen: (prev, next) =>
          next.messageId != prev.messageId &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<FriendsCubit>();
        return AppScaffold(
          onRefresh: () async => cubit.load(),
          header: AppPageHeader(
            title: 'Friends',
            action: AppHeaderAction(
              tooltip: 'Add a friend',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onTap: _openAddSheet,
            ),
          ),
          body: state.friends == null
              ? (state.failed
                    ? LoadErrorView(onRetry: cubit.load)
                    : const Center(child: VitalUpLoader()))
              : _body(state, cubit),
        );
      },
    );
  }

  Widget _body(FriendsState state, FriendsCubit cubit) {
    final tab = _tab(state);
    final counts = {
      _Tab.friends: state.accepted.length,
      _Tab.requests: state.incoming.length,
      _Tab.sent: state.outgoing.length,
    };
    final showSearch = counts[tab]! >= _searchFrom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedControl<_Tab>(
          values: _Tab.values,
          selected: tab,
          label: (t) {
            final name = switch (t) {
              _Tab.friends => 'Friends',
              _Tab.requests => 'Requests',
              _Tab.sent => 'Sent',
            };
            final n = counts[t]!;
            return n > 0 ? '$name $n' : name;
          },
          onChanged: (t) => setState(() {
            _picked = t;
            _query = '';
            _search.clear();
          }),
        ),
        const SizedBox(height: AppDimens.space16),
        if (showSearch) ...[
          AppTextField(
            controller: _search,
            hint: 'Search by name or username',
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            maxLength: InputLimits.search,
            onChanged: (v) => setState(() => _query = sanitizeText(v)),
          ),
          const SizedBox(height: AppDimens.space16),
        ],
        switch (tab) {
          _Tab.friends => _friendsTab(state),
          _Tab.requests => _requestsTab(state, cubit),
          _Tab.sent => _sentTab(state, cubit),
        },
      ],
    );
  }

  Widget _friendsTab(FriendsState state) {
    if (state.accepted.isEmpty) {
      return _EmptyFriends(myUsername: widget.myUsername, onAdd: _openAddSheet);
    }
    final items = [
      for (final item in state.rankedFriendsAndSelf)
        // The caller's row is the reference point, not a search result.
        if (!(item.isMe && _query.isNotEmpty) &&
            _matches(item.username, item.displayName))
          item,
    ];
    if (items.isEmpty) return const _NoMatches();
    return AppListGroup(
      title: 'Ranked by all-time points',
      children: [
        for (final item in items)
          _PersonRow(
            friend:
                item.friend ??
                Friend(
                  userId: item.userId,
                  username: item.username,
                  fullName: item.displayName,
                  avatarUrl: item.avatarUrl,
                  level: item.level,
                  status: FriendStatus.accepted,
                ),
            isMe: item.isMe,
            showRank: true,
            rank: item.rank,
            subtitle:
                'Level ${item.level} · ${_points.format(item.points)} pts',
            trailing: item.friend != null && state.busy.contains(item.userId)
                ? const _Busy()
                : null,
            onTap: item.friend == null
                ? null
                : () => PlayerInspectSheet.show(
                    context,
                    friend: item.friend!,
                    onRemove: () => _confirmRemove(item.friend!),
                  ),
          ),
      ],
    );
  }

  Widget _requestsTab(FriendsState state, FriendsCubit cubit) {
    if (state.incoming.isEmpty) {
      return const _TabEmpty(
        icon: Icons.mark_email_unread_outlined,
        title: 'No requests',
        message: 'Friend requests you receive show up here.',
      );
    }
    final people = [
      for (final f in state.incoming)
        if (_matches(f.username, f.fullName)) f,
    ];
    if (people.isEmpty) return const _NoMatches();
    return AppListGroup(
      children: [
        for (final f in people)
          _PersonRow(
            friend: f,
            subtitle: _levelLine(f),
            onTap: () => _showProfile(f),
            trailing: state.busy.contains(f.userId)
                ? const _Busy()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RowButton(
                        label: 'Decline',
                        onTap: () => cubit.respond(f, accept: false),
                      ),
                      const SizedBox(width: AppDimens.space6),
                      _RowButton(
                        label: 'Accept',
                        filled: true,
                        onTap: () => cubit.respond(f, accept: true),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _sentTab(FriendsState state, FriendsCubit cubit) {
    if (state.outgoing.isEmpty) {
      return _TabEmpty(
        icon: Icons.outgoing_mail,
        title: 'No pending requests',
        message: 'Requests you send wait here until they accept.',
        action: AppSecondaryButton(label: 'Add a friend', onTap: _openAddSheet),
      );
    }
    final people = [
      for (final f in state.outgoing)
        if (_matches(f.username, f.fullName)) f,
    ];
    if (people.isEmpty) return const _NoMatches();
    return AppListGroup(
      children: [
        for (final f in people)
          _PersonRow(
            friend: f,
            subtitle: 'Request sent',
            onTap: () => _showProfile(f),
            trailing: state.busy.contains(f.userId)
                ? const _Busy()
                : _RowButton(label: 'Cancel', onTap: () => cubit.remove(f)),
          ),
      ],
    );
  }

  static String _levelLine(Friend f) => [
    if (f.fullName?.trim().isNotEmpty ?? false) '@${f.username}',
    'Level ${f.level}',
  ].join(' · ');
}

/// Small pill action inside a row ("Accept", "Decline", "Cancel").
class _RowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _RowButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Material(
      color: filled ? primary : context.vColors.primaryTint,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space12,
            vertical: AppDimens.space6,
          ),
          child: Text(
            label,
            style: context.text.labelLarge?.copyWith(
              color: filled ? context.colors.onPrimary : primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet centred empty state for a tab.
class _TabEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _TabEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space32),
      child: Column(
        children: [
          AppIconBadge(
            size: AppDimens.iconBadgeLarge,
            color: grey,
            icon: Icon(icon),
          ),
          const SizedBox(height: AppDimens.space12),
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: AppDimens.space4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: grey),
          ),
          if (action != null) ...[
            const SizedBox(height: AppDimens.space16),
            action!,
          ],
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) => const _TabEmpty(
    icon: Icons.search_off_rounded,
    title: 'No matches',
    message: 'Check the spelling or try another name.',
  );
}

Color _rankColor(int rank) => switch (rank) {
  1 => AppColors.rankGold,
  2 => AppColors.rankSilver,
  _ => AppColors.rankBronze,
};

/// One row inside a list group: optional rank, avatar, name, subtitle and
/// a trailing action (or a chevron when tappable). The caller's row is
/// tinted.
class _PersonRow extends StatelessWidget {
  final Friend friend;
  final String subtitle;
  final bool isMe;
  final bool showRank;
  final int? rank;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _PersonRow({
    required this.friend,
    required this.subtitle,
    this.isMe = false,
    this.showRank = false,
    this.rank,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final name = friend.fullName?.trim();
    final title = name != null && name.isNotEmpty
        ? name
        : '@${friend.username}';
    final r = rank;

    return Material(
      color: isMe ? context.vColors.primaryTint : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space10,
          ),
          child: Row(
            children: [
              if (showRank)
                SizedBox(
                  width: AppDimens.rankColumnWidth,
                  child: r != null && r <= 3
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: GameIcon(
                            GamificationIcons.leaderboardRank(r)!,
                            fallback: Icons.military_tech_rounded,
                            size: AppDimens.iconLg,
                            color: _rankColor(r),
                          ),
                        )
                      : Text(
                          r == null ? '–' : '$r',
                          style: context.text.titleSmall?.copyWith(
                            color: isMe ? context.colors.primary : grey,
                          ),
                        ),
                ),
              UserAvatar(
                username: friend.username,
                url: friend.avatarUrl,
                size: AppDimens.iconBadge,
                ringColor: isMe ? context.colors.primary : null,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NameWithYouTag(
                      name: title,
                      isMe: isMe,
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppDimens.space8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: AppDimens.space4),
                const AppChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppDimens.iconLg,
    child: CircularProgressIndicator(
      strokeWidth: AppDimens.borderThick,
      strokeCap: StrokeCap.round,
    ),
  );
}

class _EmptyFriends extends StatelessWidget {
  final String? myUsername;
  final VoidCallback onAdd;

  const _EmptyFriends({required this.onAdd, this.myUsername});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AppIconBadge(
              size: AppDimens.iconBadgeLarge,
              icon: const Icon(Icons.group_add_rounded),
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            'No friends yet',
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            'Add friends by username to compare progress and start '
            'challenges.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          AppPrimaryButton(label: 'Add a friend', onTap: onAdd),
          const SizedBox(height: AppDimens.space8),
          InviteButtons(myUsername: myUsername),
        ],
      ),
    );
  }
}

/// Send a request by username, or share an invite. Closes once a request
/// goes through; problems show under the field.
class _AddFriendSheet extends StatefulWidget {
  final String? myUsername;

  const _AddFriendSheet({this.myUsername});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _username = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final cubit = context.read<FriendsCubit>();
    if (cubit.state.sending) return;
    setState(() => _error = null);
    final sent = await cubit.send(_username.text);
    if (!mounted) return;
    if (sent) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = cubit.state.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sending = context.select((FriendsCubit c) => c.state.sending);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        AppDimens.sectionGap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a friend', style: context.text.headlineSmall),
          const SizedBox(height: AppDimens.space4),
          Text(
            'Send a request with their VitalUp username.',
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          AppTextField(
            controller: _username,
            hint: '@username',
            prefixIcon: Icons.person_search_rounded,
            autofocus: true,
            error: _error,
            textInputAction: TextInputAction.send,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              // Usernames: letters, numbers, dots and underscores; a
              // leading @ is fine.
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._@]')),
              LengthLimitingTextInputFormatter(InputLimits.usernameMax + 1),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: AppDimens.space12),
          AppPrimaryButton(
            label: 'Send request',
            isLoading: sending,
            onTap: _send,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          Text('Or let them add you', style: context.text.titleSmall),
          const SizedBox(height: AppDimens.space8),
          InviteButtons(myUsername: widget.myUsername),
        ],
      ),
    );
  }
}
