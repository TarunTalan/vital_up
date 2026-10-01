import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

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

  Future<void> _copyUsername(String username) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: '@$username'));
    messenger.showSnackBar(
      SnackBar(
        content: Text('Copied @$username — share it so friends can add you'),
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

  @override
  Widget build(BuildContext context) {
    final me = widget.myUsername;
    return BlocConsumer<FriendsCubit, FriendsState>(
      listenWhen: (prev, next) => next.messageId != prev.messageId,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<FriendsCubit>();
        final friends = state.friends;
        return AppScaffold(
          header: const AppPageHeader(title: 'Friends'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Add a friend', style: context.text.titleSmall),
                    const SizedBox(height: AppDimens.space4),
                    Text(
                      'Send a request with their VitalUp username.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space12),
                    AppTextField(
                      controller: _username,
                      hint: '@username',
                      prefixIcon: Icons.person_search_rounded,
                      textInputAction: TextInputAction.send,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      onSubmitted: (_) => _send(),
                    ),
                    const SizedBox(height: AppDimens.space12),
                    AppPrimaryButton(
                      label: 'Send request',
                      isLoading: state.sending,
                      onTap: _send,
                    ),
                    if (me != null && me.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.space8),
                      AppSecondaryButton(
                        label: 'Copy my username (@$me)',
                        leadingIcon: const Icon(
                          Icons.copy_rounded,
                          size: AppDimens.iconSm,
                        ),
                        onTap: () => _copyUsername(me),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.sectionGap),
              if (friends == null)
                state.failed
                    ? LoadErrorView(onRetry: cubit.load)
                    : const Center(child: CircularProgressIndicator())
              else ...[
                if (state.incoming.isNotEmpty) ...[
                  _SectionTitle('Requests (${state.incoming.length})'),
                  for (final f in state.incoming)
                    _FriendRow(
                      friend: f,
                      busy: state.busy.contains(f.userId),
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
                  const SizedBox(height: AppDimens.space12),
                ],
                _SectionTitle('Friends (${state.accepted.length})'),
                if (state.accepted.isEmpty)
                  const AppInfoNote(
                    message:
                        'No friends yet. Add someone by username to '
                        'compete on your friends leaderboard.',
                  ),
                for (final f in state.accepted)
                  _FriendRow(
                    friend: f,
                    busy: state.busy.contains(f.userId),
                    trailing: IconButton(
                      tooltip: 'Remove friend',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _confirmRemove(f),
                    ),
                  ),
                if (state.outgoing.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.space12),
                  const _SectionTitle('Sent'),
                  for (final f in state.outgoing)
                    _FriendRow(
                      friend: f,
                      subtitle: 'Waiting for them to accept',
                      busy: state.busy.contains(f.userId),
                      trailing: TextButton(
                        onPressed: () => cubit.remove(f),
                        child: const Text('Cancel'),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimens.space12),
    child: Text(text, style: context.text.titleMedium),
  );
}

class _FriendRow extends StatelessWidget {
  final Friend friend;
  final Widget trailing;
  final String? subtitle;
  final bool busy;

  const _FriendRow({
    required this.friend,
    required this.trailing,
    this.subtitle,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space8),
      child: AppCard(
        width: double.infinity,
        padding: AppDimens.cardPaddingCompact,
        child: Row(
          children: [
            UserAvatar(username: friend.username, url: friend.avatarUrl),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${friend.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle ?? 'Level ${friend.level}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: AppDimens.iconLg,
                child: CircularProgressIndicator(
                  strokeWidth: AppDimens.borderThick,
                ),
              )
            else
              trailing,
          ],
        ),
      ),
    );
  }
}
