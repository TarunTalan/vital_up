import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/core/di/injection_container.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onLogout;

  const ProfilePage({
    super.key,
    this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _PhotoAction { camera, gallery, remove }

class _ProfilePageState extends State<ProfilePage> {
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

  void _handleLogout(BuildContext context) {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    _showLogoutDialog(context);
  }

  void _showLogoutDialog(BuildContext context) {
    final errorColor = context.colors.error;
    final cubit = context.read<AuthCubit>();

    showSmoothDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () {
              Navigator.of(context).pop();
              cubit.logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _initial(ProfileEntity profile) {
    if (profile.fullName.isNotEmpty) return profile.fullName.substring(0, 1).toUpperCase();
    if (profile.username.isNotEmpty) return profile.username.substring(0, 1).toUpperCase();
    return 'U';
  }

  Widget _buildAvatar(ProfileEntity profile, double size, TextStyle? initialStyle) {
    final photoUrl = profile.photoUrl;
    final uploading = context.read<ProfileCubit>().state is ProfilePhotoUpdating;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        width: size,
        height: size,
        color: context.vColors.primaryTint,
        child: uploading
            ? Center(
                child: SizedBox.square(
                  dimension: size / 3,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimens.borderThick,
                    color: context.colors.primary,
                  ),
                ),
              )
            : photoUrl != null
                ? Image.network(
                    photoUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        _initial(profile),
                        style: initialStyle?.copyWith(color: context.colors.primary),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _initial(profile),
                      style: initialStyle?.copyWith(color: context.colors.primary),
                    ),
                  ),
      ),
    );
  }

  Future<void> _showPhotoOptions(ProfileEntity profile) async {
    final cubit = context.read<ProfileCubit>();
    if (cubit.state is ProfilePhotoUpdating) return;

    final choice = await showAppBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
              ),
              if (profile.photoUrl != null)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: context.colors.error),
                  title: Text(
                    'Remove photo',
                    style: TextStyle(color: context.colors.error),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.remove),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == _PhotoAction.remove) {
      final confirmed = await showSmoothDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove photo?'),
          content: const Text('Your profile will show your initial instead.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed == true) await cubit.removePhoto();
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: choice == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return;
      await cubit.uploadPhoto(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        choice == _PhotoAction.camera
            ? 'Camera access is needed to take a photo. You can allow it in Settings.'
            : 'Photo access is needed to choose a picture. You can allow it in Settings.',
      );
    }
  }

  void _showEditIdentitySheet(BuildContext context, ProfileEntity profile) {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController(text: profile.fullName);
    final usernameController = TextEditingController(text: profile.username);
    
    // Formatting DOB
    String dobDisplay = profile.dob;
    if (dobDisplay.length == 8) {
      dobDisplay = '${dobDisplay.substring(0, 2)}/${dobDisplay.substring(2, 4)}/${dobDisplay.substring(4, 8)}';
    }
    final dobController = TextEditingController(text: dobDisplay);
    
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppDimens.space16,
          left: context.gutter,
          right: context.gutter,
          top: AppDimens.space16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Profile', style: context.text.titleLarge),
              const SizedBox(height: AppDimens.space24),
              AppTextField(
                controller: fullNameController,
                label: 'Full Name',
                prefixIcon: Icons.badge_rounded,
                validator: (val) {
                  if (val.trim().isEmpty) return 'Full name is required';
                  if (val.trim().length < 2) return 'Must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppDimens.space16),
              AppTextField(
                controller: usernameController,
                label: 'Username',
                prefixIcon: Icons.alternate_email_rounded,
                validator: (val) {
                  if (val.trim().isEmpty) return 'Username is required';
                  if (val.trim().length < 3) return 'Must be at least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppDimens.space16),
              AppTextField(
                controller: dobController,
                label: 'Date of Birth',
                prefixIcon: Icons.calendar_month_rounded,
                readOnly: true,
                onTap: () async {
                  DateTime initialDate = DateTime(2000, 1, 1);
                  if (dobController.text.isNotEmpty) {
                    try {
                      final parts = dobController.text.split('/');
                      if (parts.length == 3) {
                        initialDate = DateTime(
                          int.parse(parts[2]),
                          int.parse(parts[1]),
                          int.parse(parts[0]),
                        );
                      }
                    } catch (_) {}
                  }

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );

                  if (picked != null) {
                    dobController.text = DateFormat('dd/MM/yyyy').format(picked);
                  }
                },
                suffix: const Icon(Icons.arrow_drop_down_rounded),
                validator: (val) {
                  if (val.trim().isEmpty) return 'Date of birth is required';
                  return null;
                },
              ),
              const SizedBox(height: AppDimens.space24),
              AppPrimaryButton(
                label: 'Save Changes',
                onTap: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final rawDob = dobController.text.trim().replaceAll('/', '');
                    final updated = profile.copyWith(
                      fullName: fullNameController.text.trim(),
                      username: usernameController.text.trim(),
                      dob: rawDob,
                    );
                    context.read<ProfileCubit>().updateProfile(updated);
                    Navigator.pop(sheetContext);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileSaveSuccess) {
          showSuccessSnackBar(context, 'Profile updated successfully!');
        } else if (state is ProfilePhotoUpdated) {
          showSuccessSnackBar(
            context,
            state.removed ? 'Profile photo removed' : 'Profile photo updated',
          );
        } else if (state is ProfilePhotoFailed) {
          showErrorSnackBar(context, state.message);
        } else if (state is ProfileError) {
          showErrorSnackBar(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is ProfileLoading || state is ProfileInitial) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: AuthBackground(child: Center(child: VitalUpLoader())),
          );
        }

        ProfileEntity? profile;
        if (state is ProfileLoaded) {
          profile = state.profile;
        } else if (state is ProfileSaveSuccess) {
          profile = state.updatedProfile;
        } else if (state is ProfileSaving) {
          profile = state.currentProfile;
        } else if (state is ProfilePhotoUpdating || state is ProfilePhotoUpdated || state is ProfilePhotoFailed) {
          profile = (state as dynamic).profile;
        } else if (state is ProfileError) {
          return _buildErrorView();
        }

        if (profile == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: AuthBackground(
              child: Center(
                child: Text(
                  'Profile not initialized.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ),
            ),
          );
        }

        return AppScaffold(
          header: const AppPageHeader(title: 'Profile'),
          body: Column(
            children: [
              _buildHeaderCard(profile),
              const SizedBox(height: AppDimens.space24),
              _buildNavigationMenu(),
              SizedBox(height: context.h(80)), // Padding for nav bar
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(ProfileEntity profile) {
    final v = context.vColors;
    final avatarSize = context.w(AppDimens.avatarLarge);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space24),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
        boxShadow: AppShadows.soft,
      ),
      child: BlocBuilder<GamificationCubit, GamificationState>(
        builder: (context, gameState) {
          final stats = gameState.stats ?? PlayerStats.empty;
          final currentLevel = stats.level.level;
          final tier = LevelTierConfig.forLevel(currentLevel, title: stats.level.title);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _showPhotoOptions(profile),
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
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
                          child: _buildAvatar(
                            profile,
                            avatarSize,
                            context.text.headlineMedium,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: LevelBadgeWidget(
                          level: currentLevel,
                          title: stats.level.title,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName.isNotEmpty ? profile.fullName : 'VitalUp User',
                                    style: context.text.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppDimens.space4),
                                  Text(
                                    '@${profile.username}',
                                    style: context.text.bodySmall?.copyWith(color: v.grayText),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimens.space8),
                            GestureDetector(
                              onTap: () => _showEditIdentitySheet(context, profile),
                              child: SvgPicture.asset(
                                'assets/icons/edit.svg',
                                width: AppDimens.iconSm,
                                height: AppDimens.iconSm,
                                colorFilter: ColorFilter.mode(context.colors.primary, BlendMode.srcIn),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.space8),
                        LevelTagPill(
                          level: currentLevel,
                          title: stats.level.title,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatItem('Points', stats.totalPoints.toString(), 'assets/icons/flash.svg', context.vColors.warning ?? Colors.orange),
                    const SizedBox(width: AppDimens.space24),
                    _buildStatItem('Streak', '${stats.streak}d', 'assets/icons/streak.svg', context.colors.error),
                    const SizedBox(width: AppDimens.space24),
                    _buildStatItem('Best Streak', '${stats.longestStreak}d', 'assets/icons/streak_1.svg', context.colors.error),
                    const SizedBox(width: AppDimens.space24),
                    _buildStatItem('Fitness XP', stats.pointsIn(ScoreCategory.fitness).toString(), 'assets/icons/barbell.svg', AppColors.scoreFitness),
                    const SizedBox(width: AppDimens.space24),
                    _buildStatItem('Diet XP', stats.pointsIn(ScoreCategory.nutrition).toString(), 'assets/icons/fork_knife.svg', AppColors.scoreNutrition),
                  ],
                ),
              ),
              _buildBadgesRow(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBadgesRow() {
    return FutureBuilder<List<GameBadge>>(
      future: sl<GamificationRepository>().getBadges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final earned = snapshot.data!.where((b) => b.earned).take(3).toList();
        if (earned.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.space24),
            Text('Achievements', style: context.text.titleSmall?.copyWith(color: context.vColors.grayText)),
            const SizedBox(height: AppDimens.space12),
            Row(
              children: earned.map((b) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Tooltip(
                  message: b.name,
                  child: Container(
                    padding: EdgeInsets.all(context.w(AppDimens.space8)),
                    decoration: BoxDecoration(
                      color: context.vColors.glassFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.vColors.glassBorder!),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/${b.iconKey}.svg',
                      width: context.w(24),
                      height: context.w(24),
                      colorFilter: ColorFilter.mode(context.colors.primary, BlendMode.srcIn),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, String iconAsset, Color iconColor) {
    return Column(
      children: [
        SvgPicture.asset(
          iconAsset,
          width: context.w(20),
          height: context.w(20),
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
        const SizedBox(height: AppDimens.space4),
        Text(value, style: context.text.titleSmall),
        Text(label, style: context.text.labelSmall?.copyWith(color: context.vColors.grayText)),
      ],
    );
  }

  Widget _buildNavigationMenu() {
    return Column(
      children: [
        _buildNavTile(
          title: 'Health & Body Metrics',
          subtitle: 'Weight, Vitals, Medical History',
          icon: 'assets/icons/weight.svg',
          onTap: () => context.pushNamed('health-details'),
        ),
        _buildNavTile(
          title: 'App Settings',
          subtitle: 'Theme, Notifications, Preferences',
          icon: 'assets/icons/settings.svg',
          onTap: () => context.pushNamed('settings'),
        ),
        _buildNavTile(
          title: 'Help & Support',
          subtitle: 'FAQs, Contact Support',
          icon: 'assets/icons/Info.svg',
          onTap: () => context.pushNamed('help-support'),
        ),
        const SizedBox(height: AppDimens.space16),
        _buildNavTile(
          title: 'Logout',
          subtitle: 'Sign out of your account',
          icon: Icons.logout_rounded,
          isDestructive: true,
          onTap: () => _handleLogout(context),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required String title,
    required String subtitle,
    required dynamic icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final v = context.vColors;
    final color = isDestructive ? context.colors.error : context.colors.onSurface;
    final iconColor = isDestructive ? context.colors.error : context.colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Ink(
            padding: const EdgeInsets.all(AppDimens.space16),
            decoration: BoxDecoration(
              color: v.glassFill,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: v.glassBorder!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimens.space12),
                  decoration: BoxDecoration(
                    color: isDestructive ? context.colors.error.withValues(alpha: 0.1) : context.vColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: icon is String
                      ? SvgPicture.asset(
                          icon,
                          width: context.w(24),
                          height: context.w(24),
                          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                        )
                      : Icon(icon as IconData, color: iconColor),
                ),
                const SizedBox(width: AppDimens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleSmall?.copyWith(color: color),
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        subtitle,
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive ? context.colors.error.withValues(alpha: 0.5) : v.grayText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconBadge(
                  icon: const Icon(Icons.error_outline_rounded),
                  color: context.colors.error,
                  size: AppDimens.iconXxl,
                ),
                const SizedBox(height: AppDimens.space16),
                Text(
                  'Failed to load profile',
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: AppDimens.space8),
                Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
                const SizedBox(height: AppDimens.sectionGap),
                AppPrimaryButton(
                  label: 'Retry',
                  expand: false,
                  onTap: () => context
                      .read<ProfileCubit>()
                      .loadProfile(forceRefresh: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
