import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';

import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

/// Arena section: one list with the global board, your city and the
/// communities you joined (your rank this week on each), ending in "Find
/// communities", which lists the ones you can join in a sheet.
class CommunityLeaderboardsSection extends StatelessWidget {
  const CommunityLeaderboardsSection({super.key});

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
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save your city. Try again.")),
      );
    }
  }

  void _openDiscover(BuildContext context) {
    final cubit = context.read<CommunityCubit>();
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _DiscoverSheet(
          onOpen: (c) {
            Navigator.of(context).pop();
            _openLeaderboard(context, c);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        final discover = state.discover.length;
        return AppListGroup(
          title: 'Leaderboards',
          children: [
            if (state.global case final global?)
              CommunityTile(
                community: global,
                standing: state.standings[global.id],
                onTap: () => _openLeaderboard(context, global),
              ),
            if (state.local case final local?)
              CommunityTile(
                community: local,
                standing: state.standings[local.id],
                onTap: () => _openLeaderboard(context, local),
              )
            else
              _ActionRow(
                icon: Icons.location_city_rounded,
                title: 'Add your city',
                subtitle: 'See how you rank near you',
                onTap: () => _editCity(context),
              ),
            for (final c in state.joined)
              CommunityTile(
                community: c,
                standing: state.standings[c.id],
                onTap: () => _openLeaderboard(context, c),
              ),
            if (discover > 0)
              _ActionRow(
                icon: Icons.explore_rounded,
                title: 'Find communities',
                subtitle: '$discover to join',
                onTap: () => _openDiscover(context),
              ),
          ],
        );
      },
    );
  }
}

/// A list row that leads somewhere new (set a city, find communities).
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
          vertical: AppDimens.space10,
        ),
        child: Row(
          children: [
            AppIconBadge(icon: Icon(icon), color: context.colors.primary),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      color: context.vColors.accentText,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(color: grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.space8),
            const AppChevron(),
          ],
        ),
      ),
    );
  }
}

/// Interest communities the caller hasn't joined, each with Join.
class _DiscoverSheet extends StatelessWidget {
  final ValueChanged<Community> onOpen;

  const _DiscoverSheet({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();
        final discover = state.discover;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
            AppDimens.sectionGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Find communities', style: context.text.headlineSmall),
              const SizedBox(height: AppDimens.space4),
              Text(
                'Join one to rank with people who share your goals.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
              const SizedBox(height: AppDimens.space16),
              if (discover.isEmpty)
                const AppInfoNote(
                  message: "You've joined every community. Nice.",
                )
              else
                AppListGroup(
                  children: [
                    for (final c in discover)
                      CommunityTile(
                        community: c,
                        onTap: () => onOpen(c),
                        trailing: state.busy.contains(c.id)
                            ? const SizedBox.square(
                                dimension: AppDimens.iconMd,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppDimens.borderThick,
                                  strokeCap: StrokeCap.round,
                                ),
                              )
                            : FilledButton(
                                onPressed: () => cubit.toggleMembership(c),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Join'),
                              ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A bottom sheet for Leaderboard Settings (Visibility and City selection)
class CommunitySettingsSheet extends StatelessWidget {
  const CommunitySettingsSheet({super.key});

  /// Uses the [CommunityCubit] above [context], or [cubit] when opened from
  /// outside Arena (Settings).
  static Future<void> show(BuildContext context, {CommunityCubit? cubit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit ?? context.read<CommunityCubit>(),
        child: const CommunitySettingsSheet(),
      ),
    );
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
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save your city. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDimens.space16,
        right: AppDimens.space16,
        top: AppDimens.space24,
        bottom: context.safePadding.bottom + AppDimens.space24,
      ),
      child: BlocBuilder<CommunityCubit, CommunityState>(
        builder: (context, state) {
          final cubit = context.read<CommunityCubit>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard settings', style: context.text.headlineSmall),
              const SizedBox(height: AppDimens.space24),
              AppCard(
                width: double.infinity,
                padding: AppDimens.cardPaddingCompact,
                child: state.failed
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.space16,
                        ),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: cubit.loadSettings,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text("Couldn't load settings. Retry"),
                          ),
                        ),
                      )
                    : state.loading &&
                          state.settings == const CommunitySettings()
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppDimens.space24,
                        ),
                        child: Center(child: VitalUpLoader()),
                      )
                    : Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Show me on leaderboards',
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Members see your username, avatar, points, streak, badges '
                              'and awards. When off, everyone sees only your name and '
                              'level, friends included.',
                              style: context.text.bodySmall?.copyWith(
                                color: v.grayText,
                              ),
                            ),
                            value: state.settings.leaderboardVisible,
                            onChanged: cubit.setLeaderboardVisible,
                          ),
                          const Divider(height: AppDimens.space16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'City',
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              state.settings.city ?? 'Not set',
                              style: context.text.bodySmall?.copyWith(
                                color: v.grayText,
                              ),
                            ),
                            trailing: SvgPicture.asset(
                              TrackerIcons.edit,
                              width: AppDimens.iconSm,
                              height: AppDimens.iconSm,
                              colorFilter: ColorFilter.mode(
                                v.grayText ?? context.colors.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                            onTap: () => _editCity(context),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
