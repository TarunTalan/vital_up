import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';

/// A compact, interactive top-bar avatar button that displays the user's
/// avatar, glowing level tier frame ring, and mini level badge.
class TopBarProfileAvatarButton extends StatelessWidget {
  const TopBarProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GamificationCubit, GamificationState>(
      builder: (context, gameState) {
        final level = gameState.stats?.level.level ?? 1;
        final tier = LevelTierConfig.forLevel(level);

        return BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, profState) {
            String? avatarUrl;
            String username = 'U';
            if (profState is ProfileLoaded) {
              avatarUrl = profState.profile.photoUrl;
              username = profState.profile.username.isNotEmpty
                  ? profState.profile.username
                  : profState.profile.fullName;
            } else if (profState is ProfilePhotoUpdated) {
              avatarUrl = profState.profile.photoUrl;
              username = profState.profile.username;
            }

            return Tooltip(
              message: 'Player Profile (Lv $level)',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pushNamed('profile'),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  child: Container(
                    width: AppDimens.headerActionSize,
                    height: AppDimens.headerActionSize,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: tier.glowColor.withValues(alpha: 0.35),
                                blurRadius: AppDimens.space8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: UserAvatar(
                            username: username,
                            url: avatarUrl,
                            size: 34,
                            ringColor: tier.borderColor,
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -3,
                          child: LevelBadgeWidget(
                            level: level,
                            size: 15,
                            showGlow: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
