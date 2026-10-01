import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _dobController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _bpTopController;
  late TextEditingController _bpBottomController;
  late TextEditingController _bpmController;
  late TextEditingController _sleepController;
  late TextEditingController _oxygenController;
  late TextEditingController _conditionsController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicinesController;

  String _gender = '';
  String _weightUnit = 'kg';
  String _heightUnit = 'cm';
  String _activity = '';
  String _smokes = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize empty controllers
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _dobController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _bpTopController = TextEditingController();
    _bpBottomController = TextEditingController();
    _bpmController = TextEditingController();
    _sleepController = TextEditingController();
    _oxygenController = TextEditingController();
    _conditionsController = TextEditingController();
    _allergiesController = TextEditingController();
    _medicinesController = TextEditingController();

    // Trigger load only if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ProfileCubit>();
      if (cubit.state is ProfileInitial || cubit.state is ProfileError) {
        cubit.loadProfile();
      }
    });
  }

  void _populateFields(ProfileEntity profile) {
    _fullNameController.text = profile.fullName;
    _usernameController.text = profile.username;
    _dobController.text = _formatDobDisplay(profile.dob);
    _weightController.text = profile.weight;
    _heightController.text = profile.height;
    _bpTopController.text = profile.bloodPressureTop;
    _bpBottomController.text = profile.bloodPressureBottom;
    _bpmController.text = profile.bpm;
    _sleepController.text = profile.sleep;
    _oxygenController.text = profile.oxygenLevel;
    _conditionsController.text = profile.healthConditions;
    _allergiesController.text = profile.allergies;
    _medicinesController.text = profile.medicines;

    _gender = profile.gender;
    _weightUnit = profile.weightUnit.isEmpty ? 'kg' : profile.weightUnit;
    _heightUnit = profile.heightUnit.isEmpty ? 'cm' : profile.heightUnit;
    _activity = profile.activity;
    _smokes = profile.smokes;
  }

  String _formatDobDisplay(String rawDob) {
    if (rawDob.length == 8) {
      // DDMMYYYY to DD/MM/YYYY
      return '${rawDob.substring(0, 2)}/${rawDob.substring(2, 4)}/${rawDob.substring(4, 8)}';
    }
    return rawDob;
  }

  String _formatDobRaw(String formattedDob) {
    return formattedDob.replaceAll('/', '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bpTopController.dispose();
    _bpBottomController.dispose();
    _bpmController.dispose();
    _sleepController.dispose();
    _oxygenController.dispose();
    _conditionsController.dispose();
    _allergiesController.dispose();
    _medicinesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    DateTime initialDate = DateTime(2000, 1, 1);
    
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('/');
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
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: context.colors.copyWith(
              onPrimary: context.vColors.buttonText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _saveProfile(ProfileEntity originalProfile) {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = originalProfile.copyWith(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        dob: _formatDobRaw(_dobController.text.trim()),
        gender: _gender,
        weight: _weightController.text.trim(),
        weightUnit: _weightUnit,
        height: _heightController.text.trim(),
        heightUnit: _heightUnit,
        bloodPressureTop: _bpTopController.text.trim(),
        bloodPressureBottom: _bpBottomController.text.trim(),
        bpm: _bpmController.text.trim(),
        sleep: _sleepController.text.trim(),
        oxygenLevel: _oxygenController.text.trim(),
        healthConditions: _conditionsController.text.trim(),
        allergies: _allergiesController.text.trim(),
        medicines: _medicinesController.text.trim(),
        activity: _activity,
        smokes: _smokes,
      );

      context.read<ProfileCubit>().updateProfile(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          _populateFields(state.profile);
        } else if (state is ProfileSaveSuccess) {
          _populateFields(state.updatedProfile);
          setState(() => _isEditing = false);
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
        } else if (state is ProfilePhotoUpdating) {
          profile = state.profile;
        } else if (state is ProfilePhotoUpdated) {
          profile = state.profile;
        } else if (state is ProfilePhotoFailed) {
          profile = state.profile;
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

        final isSaving = state is ProfileSaving;
        final loadedProfile = profile;
        // Segment + container/outer padding + container border + indicator weight.
        final tabBarHeight = AppDimens.segmentHeight +
            AppDimens.space8 * 4 +
            AppDimens.borderThin * 2 +
            AppDimens.borderThick;
        final headerHeight = context.h(AppDimens.profileHeaderHeight);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AuthBackground(
            child: Form(
              key: _formKey,
              child: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverOverlapAbsorber(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                      sliver: SliverAppBar(
                        expandedHeight: headerHeight + tabBarHeight,
                        floating: false,
                        pinned: true,
                        forceElevated: innerBoxIsScrolled,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        flexibleSpace: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final topPadding = context.safePadding.top;
                            final collapsedHeight =
                                kToolbarHeight + tabBarHeight + topPadding;
                            final isCollapsed =
                                constraints.maxHeight <= collapsedHeight + AppDimens.space20;
                            return _buildHeaderBackground(
                              loadedProfile,
                              topPadding: topPadding,
                              tabBarHeight: tabBarHeight,
                              isCollapsed: isCollapsed,
                            );
                          },
                        ),
                        actions: [
                          ..._buildHeaderActions(loadedProfile, isSaving),
                          SizedBox(width: context.gutter),
                        ],
                        bottom: PreferredSize(
                          preferredSize: Size.fromHeight(tabBarHeight),
                          child: _buildTabBar(),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabScroll(_buildAccountTab(loadedProfile)),
                    _buildTabScroll(_buildHealthTab(loadedProfile)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                  onTap: () => context.read<ProfileCubit>().loadProfile(),
                ),
              ],
            ),
          ),
        ),
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

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.vColors.primaryTint,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      // Falls back to the tint + initial instead of throwing on a dead URL.
      onBackgroundImageError: photoUrl != null ? (_, _) {} : null,
      child: uploading
          ? SizedBox.square(
              dimension: size / 3,
              child: CircularProgressIndicator(
                strokeWidth: AppDimens.borderThick,
                color: context.colors.primary,
              ),
            )
          : photoUrl == null
              ? Text(
                  _initial(profile),
                  style: initialStyle?.copyWith(color: context.colors.primary),
                )
              : null,
    );
  }

  /// Camera / gallery / remove sheet for the profile photo.
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
        // Avatars render at most ~100dp; this keeps uploads small.
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

  Widget _buildHeaderBackground(
    ProfileEntity profile, {
    required double topPadding,
    required double tabBarHeight,
    required bool isCollapsed,
  }) {
    final v = context.vColors;
    final avatarSize = context.w(AppDimens.avatarLarge);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.headerBlur / 2,
          sigmaY: AppDimens.headerBlur / 2,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: v.glassFill,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [v.primaryFill!, Colors.transparent],
            ),
            border: Border(bottom: BorderSide(color: v.glassBorder!)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                background: Padding(
                  padding: EdgeInsets.only(
                    top: topPadding + kToolbarHeight / 2,
                    bottom: tabBarHeight,
                    left: context.gutter,
                    right: context.gutter,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                padding: const EdgeInsets.all(AppDimens.borderThick),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.colors.primary,
                                    width: AppDimens.borderThick,
                                  ),
                                  boxShadow: AppShadows.inputFocus,
                                ),
                                child: _buildAvatar(
                                  profile,
                                  avatarSize,
                                  context.text.headlineMedium,
                                ),
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _showPhotoOptions(profile),
                                    child: Container(
                                      padding: const EdgeInsets.all(AppDimens.space6),
                                      decoration: BoxDecoration(
                                        color: context.colors.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: AppShadows.shadowY,
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: AppDimens.iconXs,
                                        color: v.buttonText,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.space12),
                          Text(
                            profile.fullName.isNotEmpty ? profile.fullName : 'VitalUp User',
                            textAlign: TextAlign.center,
                            style: context.text.headlineMedium,
                          ),
                          const SizedBox(height: AppDimens.space4),
                          Text(
                            '@${profile.username}',
                            style: context.text.bodyMedium?.copyWith(color: v.grayText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: AppDurations.medium,
                opacity: isCollapsed ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + AppDimens.space12,
                      left: context.gutter,
                      right: context.gutter +
                          AppDimens.headerActionSize * 2 +
                          AppDimens.space8 * 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAvatar(
                          profile,
                          AppDimens.avatarSmall,
                          context.text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: AppDimens.space8),
                        Flexible(
                          child: Text(
                            profile.fullName.isNotEmpty ? profile.fullName : 'Profile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHeaderActions(ProfileEntity profile, bool isSaving) {
    const gap = SizedBox(width: AppDimens.space8);
    if (!_isEditing) {
      return [
        AppHeaderAction(
          icon: const Icon(Icons.settings_rounded),
          onTap: () => context.pushNamed('settings'),
          tooltip: 'Settings',
        ),
        gap,
        AppHeaderAction(
          icon: const Icon(Icons.edit_rounded),
          onTap: () => setState(() => _isEditing = true),
          tooltip: 'Edit Profile',
        ),
      ];
    }
    if (isSaving) {
      return [
        SizedBox.square(
          dimension: AppDimens.headerActionSize,
          child: Center(
            child: SizedBox.square(
              dimension: AppDimens.iconLg,
              child: CircularProgressIndicator(
                strokeWidth: AppDimens.borderThick,
                color: context.colors.primary,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      AppHeaderAction(
        icon: const Icon(Icons.close_rounded),
        onTap: () {
          _populateFields(profile);
          setState(() => _isEditing = false);
        },
        tooltip: 'Cancel',
      ),
      gap,
      AppHeaderAction(
        icon: const Icon(Icons.check_rounded),
        onTap: () => _saveProfile(profile),
        tooltip: 'Save Details',
      ),
    ];
  }

  /// Figma segmented tabs: glass container, primary selected segment.
  Widget _buildTabBar() {
    final v = context.vColors;
    final labelStyle = context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    Widget tab(String text) => Tab(
          height: AppDimens.segmentHeight,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1)),
        );

    return ResponsiveCenter(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.gutter,
          vertical: AppDimens.space8,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.space8),
          decoration: BoxDecoration(
            color: v.glassFill,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(color: v.glassBorder!),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: AppDimens.borderThick,
            indicator: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              boxShadow: AppShadows.segment,
            ),
            labelPadding: EdgeInsets.zero,
            labelColor: v.buttonText,
            unselectedLabelColor: v.grayText,
            labelStyle: labelStyle,
            unselectedLabelStyle: labelStyle,
            tabs: [
              tab('Account Details'),
              tab('Health Metrics'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabScroll(Widget content) {
    return Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverToBoxAdapter(child: ResponsiveCenter(child: content)),
        ],
      ),
    );
  }

  /// Leaves room for the floating dashboard nav bar.
  EdgeInsets get _tabPadding => EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.sectionGap,
        context.gutter,
        AppDimens.navBarItemHeight +
            AppDimens.navBarPadding.vertical +
            AppDimens.navBarBottomOffset +
            AppDimens.sectionGap +
            context.safePadding.bottom,
      );

  // --- TAB 1: ACCOUNT DETAILS VIEW ---
  Widget _buildAccountTab(ProfileEntity profile) {
    return Padding(
      padding: _tabPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'Identity',
            !_isEditing
                ? [
                    _buildProfileRow(
                      icon: Icons.badge_rounded,
                      label: 'Full Name',
                      value: profile.fullName,
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Username',
                      value: '@${profile.username}',
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.email_rounded,
                      label: 'Email Address',
                      value: profile.email,
                    ),
                  ]
                : [
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.badge_rounded,
                      enabled: _isEditing,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Full name is required';
                        if (val.trim().length < 2) return 'Must be at least 2 characters';
                        return null;
                      },
                    ),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.alternate_email_rounded,
                      enabled: _isEditing,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Username is required';
                        if (val.trim().length < 3) return 'Must be at least 3 characters';
                        return null;
                      },
                    ),
                    _buildReadOnlyField(
                      label: 'Email Address',
                      value: profile.email,
                      icon: Icons.email_rounded,
                    ),
                  ],
          ),
          _buildSection(
            'Personal Demographics',
            !_isEditing
                ? [
                    _buildProfileRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Date of Birth',
                      value: _formatDobDisplay(profile.dob),
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.wc_rounded,
                      label: 'Gender',
                      value: profile.gender,
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.smoking_rooms_rounded,
                      label: 'Smoker Status',
                      value: profile.smokes,
                    ),
                  ]
                : [
                    _buildDatePickerField(
                      context: context,
                      controller: _dobController,
                      label: 'Date of Birth',
                      icon: Icons.calendar_month_rounded,
                      enabled: _isEditing,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Date of birth is required';
                        return null;
                      },
                    ),
                    _buildDropdownField(
                      label: 'Gender',
                      value: _gender,
                      icon: Icons.wc_rounded,
                      enabled: _isEditing,
                      items: const ['Male', 'Female', 'Other'],
                      onChanged: (val) => setState(() => _gender = val ?? ''),
                    ),
                    _buildDropdownField(
                      label: 'Smoker Status',
                      value: _smokes,
                      icon: Icons.smoking_rooms_rounded,
                      enabled: _isEditing,
                      items: const ['No', 'Yes', 'Occasionally'],
                      onChanged: (val) => setState(() => _smokes = val ?? ''),
                    ),
                  ],
          ),
          if (!_isEditing)
            AppSecondaryButton(
              label: 'Logout Account',
              onTap: widget.onLogout,
              leadingIcon: const Icon(Icons.logout_rounded),
              contentColor: context.colors.error,
              borderColor: context.colors.error.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  // --- TAB 2: HEALTH METRICS VIEW ---
  Widget _buildHealthTab(ProfileEntity profile) {
    final suffixStyle = context.text.bodySmall?.copyWith(color: context.vColors.grayText);
    return Padding(
      padding: _tabPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'Physical Metrics',
            !_isEditing
                ? [
                    _buildProfileRow(
                      icon: Icons.straighten_rounded,
                      label: 'Height',
                      value: profile.height.isNotEmpty ? '${profile.height} ${profile.heightUnit}' : '',
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.monitor_weight_rounded,
                      label: 'Weight',
                      value: profile.weight.isNotEmpty ? '${profile.weight} ${profile.weightUnit}' : '',
                    ),
                  ]
                : [
                    _buildValueWithUnit(
                      field: _buildTextField(
                        controller: _heightController,
                        label: 'Height',
                        icon: Icons.straighten_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        suffix: Text(_heightUnit, style: suffixStyle),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Invalid height';
                          }
                          return null;
                        },
                      ),
                      unit: _buildDropdownFieldWithoutIcon(
                        value: _heightUnit,
                        items: const ['cm', 'in'],
                        onChanged: (val) => setState(() => _heightUnit = val ?? 'cm'),
                      ),
                    ),
                    _buildValueWithUnit(
                      field: _buildTextField(
                        controller: _weightController,
                        label: 'Weight',
                        icon: Icons.monitor_weight_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        suffix: Text(_weightUnit, style: suffixStyle),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Invalid weight';
                          }
                          return null;
                        },
                      ),
                      unit: _buildDropdownFieldWithoutIcon(
                        value: _weightUnit,
                        items: const ['kg', 'lbs'],
                        onChanged: (val) => setState(() => _weightUnit = val ?? 'kg'),
                      ),
                    ),
                  ],
          ),
          _buildSection(
            'Cardiovascular & Vitals',
            !_isEditing
                ? [
                    _buildProfileRow(
                      icon: Icons.favorite_rounded,
                      label: 'Blood Pressure',
                      value: (profile.bloodPressureTop.isNotEmpty && profile.bloodPressureBottom.isNotEmpty)
                          ? '${profile.bloodPressureTop}/${profile.bloodPressureBottom} mmHg'
                          : '',
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.favorite_rounded,
                      label: 'Resting Heart Rate',
                      value: profile.bpm.isNotEmpty ? '${profile.bpm} bpm' : '',
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.opacity_rounded,
                      label: 'Blood Oxygen (SpO2)',
                      value: profile.oxygenLevel.isNotEmpty ? '${profile.oxygenLevel}%' : '',
                    ),
                  ]
                : [
                    _buildFieldPair(
                      _buildTextField(
                        controller: _bpTopController,
                        label: 'BP Systolic (Top)',
                        icon: Icons.favorite_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        placeholder: 'e.g. 120',
                      ),
                      _buildTextField(
                        controller: _bpBottomController,
                        label: 'BP Diastolic (Bottom)',
                        icon: Icons.heart_broken_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        placeholder: 'e.g. 80',
                      ),
                    ),
                    _buildFieldPair(
                      _buildTextField(
                        controller: _bpmController,
                        label: 'Resting Heart Rate',
                        icon: Icons.favorite_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        placeholder: 'e.g. 72',
                        suffix: Text('bpm', style: suffixStyle),
                      ),
                      _buildTextField(
                        controller: _oxygenController,
                        label: 'Blood Oxygen (SpO2)',
                        icon: Icons.opacity_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        placeholder: 'e.g. 98',
                        suffix: Text('%', style: suffixStyle),
                      ),
                    ),
                  ],
          ),
          _buildSection(
            'Habits & Routine Targets',
            !_isEditing
                ? [
                    _buildProfileRow(
                      icon: Icons.directions_run_rounded,
                      label: 'Activity Level',
                      value: profile.activity,
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.bedtime_rounded,
                      label: 'Daily Sleep Target',
                      value: profile.sleep.isNotEmpty ? '${profile.sleep} hrs' : '',
                    ),
                  ]
                : [
                    _buildDropdownField(
                      label: 'Activity Level',
                      value: _activity,
                      icon: Icons.directions_run_rounded,
                      enabled: _isEditing,
                      items: const ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'],
                      onChanged: (val) => setState(() => _activity = val ?? ''),
                    ),
                    _buildTextField(
                      controller: _sleepController,
                      label: 'Daily Sleep Target',
                      icon: Icons.bedtime_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      placeholder: 'e.g. 8',
                      suffix: Text('hrs', style: suffixStyle),
                    ),
                  ],
          ),
          _buildSection(
            'Medical History',
            !_isEditing
                ? [
                    _buildProfileRow(
                      icon: Icons.medical_services_rounded,
                      label: 'Health Conditions',
                      value: profile.healthConditions,
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Allergies',
                      value: profile.allergies,
                    ),
                    _buildDivider(),
                    _buildProfileRow(
                      icon: Icons.medication_rounded,
                      label: 'Current Medications',
                      value: profile.medicines,
                    ),
                  ]
                : [
                    _buildTextField(
                      controller: _conditionsController,
                      label: 'Health Conditions',
                      icon: Icons.medical_services_rounded,
                      enabled: _isEditing,
                      placeholder: 'None or list them...',
                    ),
                    _buildTextField(
                      controller: _allergiesController,
                      label: 'Allergies',
                      icon: Icons.warning_amber_rounded,
                      enabled: _isEditing,
                      placeholder: 'None or list them...',
                    ),
                    _buildTextField(
                      controller: _medicinesController,
                      label: 'Current Medications',
                      icon: Icons.medication_rounded,
                      enabled: _isEditing,
                      placeholder: 'None or list them...',
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  // --- REUSABLE UI BUILDER METHODS ---

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCaption(title),
          const SizedBox(height: AppDimens.space8),
          AppCard(
            width: double.infinity,
            padding: AppDimens.cardPaddingCompact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Two fields side by side, stacked on narrow cards.
  Widget _buildFieldPair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppDimens.smallPhoneBreakpoint) {
          return Column(children: [first, second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppDimens.space12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildValueWithUnit({required Widget field, required Widget unit}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: field),
        if (_isEditing) ...[
          const SizedBox(width: AppDimens.space8),
          SizedBox(width: context.w(AppDimens.unitFieldWidth), child: unit),
        ],
      ],
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final v = context.vColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
      child: Row(
        children: [
          AppIconBadge(icon: Icon(icon)),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(color: v.grayText),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: context.text.titleSmall?.copyWith(
                    color: value.isNotEmpty ? null : v.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: context.vColors.divider,
      height: AppDimens.borderThin,
      thickness: AppDimens.borderThin,
      indent: AppDimens.iconBadge + AppDimens.space12,
    );
  }

  /// Standard 16dp gap below each profile field.
  Widget _spaced(Widget field) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.space16),
        child: field,
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    String placeholder = '',
    String? Function(String?)? validator,
  }) {
    return _spaced(
      AppTextField(
        controller: controller,
        label: label,
        hint: placeholder,
        prefixIcon: icon,
        enabled: enabled,
        keyboardType: keyboardType,
        suffix: suffix,
        validator: validator == null ? null : (value) => validator(value),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return _spaced(
      AppDisplayField(
        label: label,
        value: value,
        placeholder: 'N/A',
        prefixIcon: icon,
      ),
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return _spaced(
      AppTextField(
        controller: controller,
        label: label,
        prefixIcon: icon,
        enabled: enabled,
        readOnly: true,
        onTap: enabled ? () => _selectDate(context) : null,
        suffix: const Icon(Icons.arrow_drop_down_rounded),
        validator: validator == null ? null : (value) => validator(value),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return _spaced(
      AppDropdownField<String>(
        label: label,
        value: items.contains(value) ? value : items.firstOrNull,
        items: items,
        itemLabel: (item) => item,
        prefixIcon: icon,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildDropdownFieldWithoutIcon({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return _spaced(
      AppDropdownField<String>(
        value: items.contains(value) ? value : items.firstOrNull,
        items: items,
        itemLabel: (item) => item,
        onChanged: onChanged,
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }
