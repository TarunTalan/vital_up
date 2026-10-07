import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';
import 'package:vital_up/features/profile/presentation/widgets/health_snapshot_card.dart';
import 'package:vital_up/features/profile/presentation/widgets/profile_photo_sheet.dart';

final _points = NumberFormat.decimalPattern();

/// The Profile tab: who you are, your body data, and your account.
/// Points, streaks and badges live in Arena; [onOpenArena] switches to it.
class ProfilePage extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onOpenArena;

  const ProfilePage({super.key, this.onLogout, this.onOpenArena});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _packageInfo = PackageInfo.fromPlatform();

  /// Kept through a pull-to-refresh so the page doesn't flash a loader.
  ProfileEntity? _lastProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ProfileCubit>();
      if (cubit.state is ProfileInitial || cubit.state is ProfileError) {
        cubit.loadProfile();
      }
    });
  }

  /// Pages under Profile share this cubit, so edits show here on return.
  Future<void> _open(String route) =>
      context.pushNamed(route, extra: context.read<ProfileCubit>());

  void _handleLogout() {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    final auth = context.read<AuthCubit>();
    showSmoothDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              auth.logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = AppPageHeader(
      title: 'Profile',
      showBack: false,
      action: AppHeaderAction(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_rounded),
        onTap: () => context.pushNamed('settings'),
      ),
    );

    return BlocConsumer<ProfileCubit, ProfileState>(
      // A failed save is reported, then the profile comes straight back.
      buildWhen: (prev, next) =>
          next is! ProfileError || prev.shownProfile == null,
      listener: (context, state) {
        // Account details shares this cubit and reports its own saves.
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        if (state is ProfilePhotoUpdated) {
          showSuccessSnackBar(
            context,
            state.removed ? 'Profile photo removed' : 'Profile photo updated',
          );
        } else if (state is ProfilePhotoFailed) {
          showErrorSnackBar(context, state.message);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final profile = cubit.currentProfile ??
            (state is ProfileLoading ? _lastProfile : null);
        _lastProfile = profile;

        if (profile == null) {
          return AppScaffold(
            header: header,
            body: Padding(
              padding: const EdgeInsets.only(top: AppDimens.space48),
              child: state is ProfileError
                  ? LoadErrorView(
                      onRetry: () => cubit.loadProfile(forceRefresh: true),
                    )
                  : const Center(child: VitalUpLoader()),
            ),
          );
        }

        return AppScaffold(
          header: header,
          onRefresh: () async {
            await Future.wait([
              cubit.loadProfile(forceRefresh: true),
              context.read<GamificationCubit>().load(),
            ]);
          },
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IdentityCard(
                profile: profile,
                uploading: state is ProfilePhotoUpdating,
                onOpen: () => _open('account-details'),
                onPhoto: () =>
                    showProfilePhotoOptions(context, cubit, profile),
                onOpenArena: widget.onOpenArena,
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppSectionHeader(
                'Health snapshot',
                actionLabel: 'Edit',
                onAction: () => _open('health-details'),
              ),
              HealthSnapshotCard(
                profile: profile,
                onTap: () => _open('health-details'),
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'Health',
                children: [
                  AppListTile(
                    icon: Icons.monitor_heart_outlined,
                    iconColor: context.colors.error,
                    title: 'Health & body',
                    subtitle: 'Body, vitals, medical history',
                    onTap: () => _open('health-details'),
                  ),
                  AppListTile(
                    icon: Icons.flag_rounded,
                    iconColor: context.vColors.success,
                    title: 'My goals',
                    subtitle: 'Water, sleep, weight and more',
                    onTap: () => context.pushNamed('my-goals'),
                  ),
                  AppListTile(
                    icon: Icons.alarm_rounded,
                    iconColor: context.vColors.warning,
                    title: 'Reminders',
                    subtitle: 'Meals, water, sleep, activity',
                    onTap: () => context.pushNamed('reminders'),
                  ),
                  AppListTile(
                    icon: Icons.medical_services_outlined,
                    iconColor: AppColors.teal,
                    title: 'Doctor health report',
                    subtitle: 'A summary to share with your doctor',
                    onTap: () => context.pushNamed('health-report'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppListGroup(
                title: 'Account',
                children: [
                  AppListTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Account details',
                    subtitle: 'Name, username, email',
                    onTap: () => _open('account-details'),
                  ),
                  AppListTile(
                    svgAsset: 'assets/icons/settings.svg',
                    title: 'Settings',
                    subtitle: 'Theme, units, privacy',
                    onTap: () => context.pushNamed('settings'),
                  ),
                  AppListTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & support',
                    subtitle: 'FAQs, Vital Assistant, contact us',
                    onTap: () => context.pushNamed('help-support'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),

              AppSecondaryButton(
                label: 'Sign out',
                contentColor: context.colors.error,
                borderColor: context.colors.error.withValues(
                  alpha: AppDimens.tintBorderAlpha,
                ),
                leadingIcon: Icon(
                  Icons.logout_rounded,
                  size: AppDimens.iconMd,
                  color: context.colors.error,
                ),
                onTap: _handleLogout,
              ),
              const SizedBox(height: AppDimens.space12),
              FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snap) => Center(
                  child: AppCaption(
                    snap.hasData
                        ? 'VitalUp ${snap.data!.version} (${snap.data!.buildNumber})'
                        : 'VitalUp',
                  ),
                ),
              ),

              // Clears the floating bottom navigation bar.
              SizedBox(height: context.safePadding.bottom + AppDimens.space16),
            ],
          ),
        );
      },
    );
  }
}

/// Photo, name, username, age and gender; tap for Account details. A single
/// Arena line underneath keeps level and points one tap away.
class _IdentityCard extends StatelessWidget {
  final ProfileEntity profile;
  final bool uploading;
  final VoidCallback onOpen;
  final VoidCallback onPhoto;
  final VoidCallback? onOpenArena;

  const _IdentityCard({
    required this.profile,
    required this.uploading,
    required this.onOpen,
    required this.onPhoto,
    this.onOpenArena,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final age = profileAge(profile);
    final gender = displayGender(profile.gender);

    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingLarge,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfileAvatar(
                profile: profile,
                uploading: uploading,
                onTap: onPhoto,
              ),
              const SizedBox(width: AppDimens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName
                          : 'VitalUp user',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      '@${profile.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                    if (age != null || gender.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.space8),
                      Wrap(
                        spacing: AppDimens.space6,
                        runSpacing: AppDimens.space6,
                        children: [
                          if (age != null) _MetaChip('$age yrs'),
                          if (gender.isNotEmpty) _MetaChip(gender),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: v.grayText),
            ],
          ),
          _ArenaStrip(onOpen: onOpenArena),
        ],
      ),
    );
  }
}

class _ArenaStrip extends StatelessWidget {
  final VoidCallback? onOpen;

  const _ArenaStrip({this.onOpen});

  @override
  Widget build(BuildContext context) {
    final stats = context.select((GamificationCubit c) => c.state.stats);
    if (stats == null) return const SizedBox.shrink();
    final grey = context.vColors.grayText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimens.space16),
        Divider(color: context.vColors.divider),
        const SizedBox(height: AppDimens.space12),
        Row(
          children: [
            const AppIconBadge(
              icon: Icon(Icons.emoji_events_rounded),
              color: AppColors.scoreBonus,
              size: AppDimens.avatarSmall,
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Level ${stats.level.level}',
                  children: [
                    TextSpan(
                      text: ' · ${_points.format(stats.totalPoints)} pts',
                      style: TextStyle(color: grey),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            if (onOpen != null) CardLink(label: 'Arena', onTap: onOpen!),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip(this.label);

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space10,
        vertical: AppDimens.space2,
      ),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: v.glassBorder!),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurface,
        ),
      ),
    );
  }
}
