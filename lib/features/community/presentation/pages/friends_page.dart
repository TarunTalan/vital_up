import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/presentation/widgets/quick_challenge_sheet.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/friend_tile.dart';
import 'package:vital_up/features/community/presentation/widgets/invite_share_card.dart';
import 'package:vital_up/features/community/presentation/widgets/player_inspect_sheet.dart';
import 'package:vital_up/features/community/presentation/widgets/public_profile_sheet.dart';

/// Add friends by username, answer requests, and manage the friends list.
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

class _FriendsView extends StatefulWidget {
  final String? myUsername;

  const _FriendsView({this.myUsername});

  @override
  State<_FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<_FriendsView> {
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final sent = await context.read<FriendsCubit>().send(_username.text);
    if (sent) _username.clear();
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
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FriendsCubit, FriendsState>(
      listenWhen: (prev, next) => next.messageId != prev.messageId,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<FriendsCubit>();
        final friends = state.friends;
        Widget gap() => const SizedBox(height: AppDimens.cardGap);
        return AppScaffold(
          onRefresh: () async => cubit.load(),
          header: const AppPageHeader(title: 'Friends'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AddFriendCard(
                controller: _username,
                sending: state.sending,
                onSend: _send,
              ),
              const SizedBox(height: AppDimens.sectionGap),
              if (friends == null)
                state.failed
                    ? LoadErrorView(onRetry: cubit.load)
                    : const Center(child: VitalUpLoader())
              else ...[
                if (state.incoming.isNotEmpty) ...[
                  AppSectionHeader('Requests', count: state.incoming.length),
                  for (final f in state.incoming) ...[
                    FriendTile(
                      friend: f,
                      busy: state.busy.contains(f.userId),
                      onTap: () => _showProfile(f),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decline',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => cubit.respond(f, accept: false),
                          ),
                          IconButton.filled(
                            tooltip: 'Accept',
                            icon: const Icon(Icons.check_rounded),
                            onPressed: () => cubit.respond(f, accept: true),
                          ),
                        ],
                      ),
                    ),
                    gap(),
                  ],
                  const SizedBox(height: AppDimens.space12),
                ],
                AppSectionHeader('Friends', count: state.accepted.length),
                if (state.accepted.isEmpty)
                  const AppInfoNote(
                    message:
                        'No friends yet. Add someone by username to compare '
                        'progress and start challenges.',
                  ),
                for (final f in state.accepted) ...[
                  FriendTile(
                    friend: f,
                    busy: state.busy.contains(f.userId),
                    onTap: () => PlayerInspectSheet.show(
                      context,
                      friend: f,
                      onRemove: () => _confirmRemove(f),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          QuickChallengeSheet.show(context, friend: f),
                      child: const Text('Challenge'),
                    ),
                  ),
                  gap(),
                ],
                if (state.outgoing.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.space12),
                  AppSectionHeader('Sent', count: state.outgoing.length),
                  for (final f in state.outgoing) ...[
                    FriendTile(
                      friend: f,
                      subtitle: 'Waiting for them to accept',
                      busy: state.busy.contains(f.userId),
                      onTap: () => _showProfile(f),
                      trailing: TextButton(
                        onPressed: () => cubit.remove(f),
                        child: const Text('Cancel'),
                      ),
                    ),
                    gap(),
                  ],
                ],
              ],
              const SizedBox(height: AppDimens.sectionGap),
              InviteShareCard(myUsername: widget.myUsername),
            ],
          ),
        );
      },
    );
  }
}

class _AddFriendCard extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _AddFriendCard({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a friend',
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            'Send a request with their VitalUp username.',
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          AppTextField(
            controller: controller,
            hint: '@username',
            prefixIcon: Icons.person_search_rounded,
            textInputAction: TextInputAction.send,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              // Usernames: letters, numbers, dots and underscores; a
              // leading @ is fine.
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._@]')),
              LengthLimitingTextInputFormatter(InputLimits.usernameMax + 1),
            ],
            onSubmitted: (_) => onSend(),
          ),
          const SizedBox(height: AppDimens.space12),
          AppPrimaryButton(
            label: 'Send request',
            isLoading: sending,
            onTap: onSend,
          ),
        ],
      ),
    );
  }
}
