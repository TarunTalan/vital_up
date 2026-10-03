import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

/// Community tab: global, local and joined communities with their
/// leaderboards, interest communities to discover, and leaderboard privacy.
class CommunityHubPage extends StatelessWidget {
  const CommunityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CommunityCubit>()..load(),
      child: const _CommunityHubView(),
    );
  }
}

class _CommunityHubView extends StatelessWidget {
  const _CommunityHubView();

  Future<void> _openLeaderboard(
    BuildContext context,
    Community community,
  ) async {
    final cubit = context.read<CommunityCubit>();
    await context.pushNamed(
      'leaderboard',
      pathParameters: {'id': community.id},
      extra: community,
    );
    cubit.load();
  }

  Future<void> _openFriends(BuildContext context) async {
    final cubit = context.read<CommunityCubit>();
    await context.pushNamed('friends', extra: cubit.state.settings.username);
    cubit.load();
  }

  Future<void> _editCity(BuildContext context) async {
    final cubit = context.read<CommunityCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final settings = cubit.state.settings;
    final result = await showAppBottomSheet<(String, String)>(
      context: context,
      builder: (_) =>
          CitySheet(city: settings.city, countryCode: settings.countryCode),
    );
    if (result == null) return;
    final ok = await cubit.setCity(result.$1, result.$2);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save your city. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityCubit, CommunityState>(
      listenWhen: (_, s) => s.message != null,
      listener: (context, s) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();
        final communities = state.communities;
        return AppScaffold(
          onRefresh: () async => cubit.load(),
          header: const AppPageHeader(title: 'Community', showBack: false),
          body: communities == null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space48),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Friends'),
                    CommunityTile(
                      community: Community.friendsOf(state.friendCount),
                      onTap: () => _openLeaderboard(
                        context,
                        Community.friendsOf(state.friendCount),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space8),
                    AppSecondaryButton(
                      label: state.incomingRequests > 0
                          ? 'Add friends · ${state.incomingRequests} new '
                                '${state.incomingRequests == 1 ? 'request' : 'requests'}'
                          : 'Add friends',
                      leadingIcon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: AppDimens.iconSm,
                      ),
                      onTap: () => _openFriends(context),
                    ),
                    const SizedBox(height: AppDimens.space8),
                    AppSecondaryButton(
                      label: 'Challenges',
                      leadingIcon: const Icon(
                        Icons.emoji_events_outlined,
                        size: AppDimens.iconSm,
                      ),
                      onTap: () => context.pushNamed('challenges'),
                    ),
                    const SizedBox(height: AppDimens.sectionGap),
                    if (state.global case final global?) ...[
                      CommunityTile(
                        community: global,
                        onTap: () => _openLeaderboard(context, global),
                      ),
                      const SizedBox(height: AppDimens.sectionGap),
                    ],
                    const _SectionTitle('Near you'),
                    if (state.local case final local?)
                      CommunityTile(
                        community: local,
                        onTap: () => _openLeaderboard(context, local),
                      )
                    else
                      AppCard(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Compete with people in your city.',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppDimens.space12),
                            AppSecondaryButton(
                              label: 'Set your city',
                              onTap: () => _editCity(context),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppDimens.sectionGap),
                    if (state.joined.isNotEmpty) ...[
                      const _SectionTitle('Your communities'),
                      for (final c in state.joined) ...[
                        CommunityTile(
                          community: c,
                          onTap: () => _openLeaderboard(context, c),
                        ),
                        const SizedBox(height: AppDimens.cardGap),
                      ],
                      const SizedBox(height: AppDimens.space12),
                    ],
                    if (state.discover.isNotEmpty) ...[
                      const _SectionTitle('Discover'),
                      for (final c in state.discover) ...[
                        CommunityTile(
                          community: c,
                          onTap: () => _openLeaderboard(context, c),
                          trailing: AppPrimaryButton(
                            label: 'Join',
                            expand: false,
                            isLoading: state.busy.contains(c.id),
                            onTap: () => cubit.toggleMembership(c),
                          ),
                        ),
                        const SizedBox(height: AppDimens.cardGap),
                      ],
                      const SizedBox(height: AppDimens.space12),
                    ],
                    const _SectionTitle('Settings'),
                    AppCard(
                      width: double.infinity,
                      padding: AppDimens.cardPaddingCompact,
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show me on leaderboards'),
                            subtitle: const Text(
                              'Public boards show your username, avatar and points. '
                              'Friends always see you.',
                            ),
                            value: state.settings.leaderboardVisible,
                            onChanged: cubit.setLeaderboardVisible,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('City'),
                            subtitle: Text(state.settings.city ?? 'Not set'),
                            trailing: SvgPicture.asset(
                              'assets/icons/edit.svg',
                              width: AppDimens.iconSm,
                              height: AppDimens.iconSm,
                              colorFilter: ColorFilter.mode(
                                context.vColors.grayText!,
                                BlendMode.srcIn,
                              ),
                            ),
                            onTap: () => _editCity(context),
                          ),
                        ],
                      ),
                    ),
                    // Clears the floating bottom nav.
                    SizedBox(
                      height: context.safePadding.bottom + AppDimens.sectionGap,
                    ),
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
