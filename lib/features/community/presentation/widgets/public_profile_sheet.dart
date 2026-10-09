import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';

class PublicProfileSheet extends StatelessWidget {
  final String username;
  final int level;
  final String? avatarUrl;

  const PublicProfileSheet({
    super.key,
    required this.username,
    required this.level,
    this.avatarUrl,
  });

  static void show(
    BuildContext context, {
    required String username,
    required int level,
    String? avatarUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider<FriendsCubit>(
        create: (_) => sl<FriendsCubit>()..load(),
        child: PublicProfileSheet(
          username: username,
          level: level,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final tier = LevelTierConfig.forLevel(level);

    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.space16,
        left: AppDimens.space16,
        right: AppDimens.space16,
      ),
      padding: const EdgeInsets.all(AppDimens.space24),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: context.w(AppDimens.avatarLarge),
                    height: context.w(AppDimens.avatarLarge),
                    padding: const EdgeInsets.all(AppDimens.borderThick),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                      border: Border.all(
                        color: tier.borderColor,
                        width: AppDimens.borderThick + 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tier.glowColor.withValues(alpha: 0.15),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusCard - AppDimens.borderThick,
                      ),
                      child: UserAvatar(
                        username: username,
                        url: avatarUrl,
                        size:
                            context.w(AppDimens.avatarLarge) -
                            AppDimens.borderThick * 2,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: LevelBadgeWidget(
                      level: level,
                      size: context.w(28),
                      showGlow: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppDimens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: context.text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimens.space4),
                    Text(
                      '@$username',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space8),
                    LevelTagPill(level: level),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space32),
          BlocBuilder<FriendsCubit, FriendsState>(
            builder: (context, state) {
              if (state.friends == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final friend = state.friends!
                  .where((f) => f.username == username)
                  .firstOrNull;

              if (friend != null) {
                if (friend.status == FriendStatus.accepted) {
                  return AppPrimaryButton(
                    label: 'Already Friends',
                    onTap: () {},
                    containerColor: context.colors.primary.withValues(
                      alpha: 0.5,
                    ),
                  );
                } else if (friend.status == FriendStatus.incoming) {
                  return Row(
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Accept Request',
                          onTap: () => context.read<FriendsCubit>().respond(
                            friend,
                            accept: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.space16),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Decline',
                          onTap: () => context.read<FriendsCubit>().respond(
                            friend,
                            accept: false,
                          ),
                          containerColor: context.colors.error,
                        ),
                      ),
                    ],
                  );
                } else {
                  return AppPrimaryButton(
                    label: 'Request Sent',
                    onTap: () {},
                    containerColor: context.colors.primary.withValues(
                      alpha: 0.5,
                    ),
                  );
                }
              }

              return AppPrimaryButton(
                label: 'Add Friend',
                isLoading: state.sending,
                onTap: () {
                  context.read<FriendsCubit>().send(username);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
