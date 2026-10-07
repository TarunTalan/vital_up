import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';

import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

/// Arena section: global and city leaderboards, then joined communities
/// and ones to discover, all as list rows.
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();
        Widget gap() => const SizedBox(height: AppDimens.cardGap);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader('Leaderboards'),
            if (state.global case final global?) ...[
              CommunityTile(
                community: global,
                onTap: () => _openLeaderboard(context, global),
              ),
              gap(),
            ],
            if (state.local case final local?)
              CommunityTile(
                community: local,
                onTap: () => _openLeaderboard(context, local),
              )
            else
              _SetCityTile(onTap: () => _editCity(context)),

            if (state.joined.isNotEmpty) ...[
              const SizedBox(height: AppDimens.sectionGap),
              AppSectionHeader('Your communities', count: state.joined.length),
              for (final c in state.joined) ...[
                CommunityTile(
                  community: c,
                  onTap: () => _openLeaderboard(context, c),
                ),
                gap(),
              ],
            ],

            if (state.discover.isNotEmpty) ...[
              const SizedBox(height: AppDimens.sectionGap),
              const AppSectionHeader('Discover'),
              for (final c in state.discover) ...[
                CommunityTile(
                  community: c,
                  onTap: () => _openLeaderboard(context, c),
                  trailing: state.busy.contains(c.id)
                      ? const SizedBox.square(
                          dimension: AppDimens.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: AppDimens.borderThick,
                          ),
                        )
                      : TextButton(
                          onPressed: () => cubit.toggleMembership(c),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Join'),
                        ),
                ),
                gap(),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Stand-in for the city board until the user has picked a city.
class _SetCityTile extends StatelessWidget {
  final VoidCallback onTap;

  const _SetCityTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      child: Row(
        children: [
          AppIconBadge(
            icon: const Icon(Icons.location_city_rounded),
            color: context.colors.primary,
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your city',
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  'Set your city to see the local leaderboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: AppDimens.iconMd,
            color: context.vColors.grayText,
          ),
        ],
      ),
    );
  }
}

/// A bottom sheet for Leaderboard Settings (Visibility and City selection)
class CommunitySettingsSheet extends StatelessWidget {
  const CommunitySettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<CommunityCubit>(),
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
                child: Column(
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
                        'Public boards show your username, avatar and points. When off, friends '
                        'still see your name and level, but not your stats.',
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
                      trailing: const Icon(
                        Icons.edit_rounded,
                        size: AppDimens.iconSm,
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
