import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
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
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
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
    final theme = Theme.of(context);
    final vColors = theme.extension<VitalUpColors>();

    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          _populateFields(state.profile);
        } else if (state is ProfileSaveSuccess) {
          _populateFields(state.updatedProfile);
          setState(() => _isEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully!'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is ProfileLoading || state is ProfileInitial) {
          return const Scaffold(
            body: Center(
              child: VitalUpLoader(),
            ),
          );
        }

        ProfileEntity? profile;
        if (state is ProfileLoaded) {
          profile = state.profile;
        } else if (state is ProfileSaveSuccess) {
          profile = state.updatedProfile;
        } else if (state is ProfileSaving) {
          profile = state.currentProfile;
        } else if (state is ProfileError) {
          // If we have an error but loaded state was present before, fallback to current values
          // otherwise show full error fallback view
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load profile',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.read<ProfileCubit>().loadProfile(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (profile == null) {
          return const Scaffold(
            body: Center(
              child: Text('Profile not initialized.'),
            ),
          );
        }

        final isSaving = state is ProfileSaving;

        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Form(
            key: _formKey,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
                NestedScrollView(
                  headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      // 1. Premium Glassmorphic Header Sliver
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                        sliver: SliverAppBar(
                          expandedHeight: 328.0, // 260 + 68 for the TabBar
                          floating: false,
                          pinned: true,
                          forceElevated: innerBoxIsScrolled,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          flexibleSpace: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints constraints) {
                              final topPadding = MediaQuery.paddingOf(context).top;
                              final collapsedHeight = 56.0 + 68.0 + topPadding;
                              final isCollapsed = constraints.maxHeight <= collapsedHeight + 20;

                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                                      child: Container(
                                        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  FlexibleSpaceBar(
                                    background: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.primary.withValues(alpha: 0.15),
                                            vColors?.blobPurple?.withValues(alpha: 0.05) ??
                                                Colors.purple.withValues(alpha: 0.05),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: SafeArea(
                                        bottom: false,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(height: 20),
                                            // Profile Avatar Container
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  width: 100,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: theme.colorScheme.primary,
                                                      width: 3.0,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                                        blurRadius: 16,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 47,
                                                    backgroundColor: theme.colorScheme.primaryContainer,
                                                    backgroundImage: profile!.photoUrl != null
                                                        ? NetworkImage(profile.photoUrl!)
                                                        : null,
                                                    child: profile.photoUrl == null
                                                        ? Text(
                                                            profile.fullName.isNotEmpty
                                                                ? profile.fullName.substring(0, 1).toUpperCase()
                                                                : profile.username.isNotEmpty
                                                                    ? profile.username.substring(0, 1).toUpperCase()
                                                                    : 'U',
                                                            style: theme.textTheme.headlineMedium?.copyWith(
                                                              color: theme.colorScheme.onPrimaryContainer,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                                if (_isEditing)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Avatar image upload is handled via Google OAuth or future updates.'),
                                                          ),
                                                        );
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.primary,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.camera_alt_rounded,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              profile.fullName.isNotEmpty ? profile.fullName : 'VitalUp User',
                                              style: theme.textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '@${profile.username}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: vColors?.grayText,
                                              ),
                                            ),
                                            const SizedBox(height: 68), // Spacer for TabBar
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: isCollapsed ? 1.0 : 0.0,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: topPadding + 12.0,
                                          left: AppTheme.hPadding,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: theme.colorScheme.primaryContainer,
                                              backgroundImage: profile!.photoUrl != null
                                                  ? NetworkImage(profile.photoUrl!)
                                                  : null,
                                              child: profile.photoUrl == null
                                                  ? Text(
                                                      profile.fullName.isNotEmpty
                                                          ? profile.fullName.substring(0, 1).toUpperCase()
                                                          : profile.username.isNotEmpty
                                                              ? profile.username.substring(0, 1).toUpperCase()
                                                              : 'U',
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        color: theme.colorScheme.onPrimaryContainer,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              profile.fullName.isNotEmpty ? profile.fullName : 'Profile',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          actions: [
                            if (!_isEditing) ...[
                              IconButton(
                                icon: const Icon(Icons.settings_rounded),
                                onPressed: () => context.pushNamed('settings'),
                                tooltip: 'Settings',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                onPressed: () => setState(() => _isEditing = true),
                                tooltip: 'Edit Profile',
                              ),
                            ]
                            else ...[
                              if (isSaving)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              else ...[
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _populateFields(profile!);
                                    setState(() => _isEditing = false);
                                  },
                                  tooltip: 'Cancel',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_rounded),
                                  onPressed: () => _saveProfile(profile!),
                                  tooltip: 'Save Details',
                                ),
                              ]
                            ]
                          ],
                          bottom: PreferredSize(
                            preferredSize: const Size.fromHeight(68.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.hPadding,
                                vertical: 10,
                              ),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: (theme.brightness == Brightness.dark
                                            ? const Color(0xFF343434)
                                            : const Color(0xFFD8D8D8))
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  dividerColor: Colors.transparent,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicator: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: vColors?.grayText,
                                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  tabs: const [
                                    Tab(text: 'Account Details'),
                                    Tab(text: 'Health Metrics'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Account details
                      Builder(
                        builder: (context) => CustomScrollView(
                          slivers: [
                            SliverOverlapInjector(
                              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                            ),
                            SliverToBoxAdapter(
                              child: _buildAccountTab(theme, vColors, profile!),
                            ),
                          ],
                        ),
                      ),
                      // TAB 2: Health metrics
                      Builder(
                        builder: (context) => CustomScrollView(
                          slivers: [
                            SliverOverlapInjector(
                              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                            ),
                            SliverToBoxAdapter(
                              child: _buildHealthTab(theme, vColors, profile!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 1: ACCOUNT DETAILS VIEW ---
  Widget _buildAccountTab(ThemeData theme, VitalUpColors? vColors, ProfileEntity profile) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppTheme.hPadding, 10, AppTheme.hPadding, 100),
      children: [
        _buildSectionHeader(theme, 'Identity'),
        if (!_isEditing)
          _buildGlassCard(
            context: context,
            children: [
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
            ],
          )
        else
          _buildGlassCard(
            context: context,
            children: [
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
        const SizedBox(height: 8),
        _buildSectionHeader(theme, 'Personal Demographics'),
        if (!_isEditing)
          _buildGlassCard(
            context: context,
            children: [
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
            ],
          )
        else
          _buildGlassCard(
            context: context,
            children: [
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
        const SizedBox(height: 30),
        // Logout Button
        if (!_isEditing)
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                foregroundColor: theme.colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout Account'),
            ),
          ),
      ],
    );
  }

  // --- TAB 2: HEALTH METRICS VIEW ---
  Widget _buildHealthTab(ThemeData theme, VitalUpColors? vColors, ProfileEntity profile) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppTheme.hPadding, 10, AppTheme.hPadding, 100),
      children: [
        _buildSectionHeader(theme, 'Physical Metrics'),
        if (!_isEditing)
          _buildGlassCard(
            context: context,
            children: [
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
            ],
          )
        else
          _buildGlassCard(
            context: context,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _heightController,
                      label: 'Height',
                      icon: Icons.straighten_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      suffix: Text(_heightUnit, style: theme.textTheme.bodySmall),
                      validator: (val) {
                        if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                          return 'Invalid height';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: _buildDropdownFieldWithoutIcon(
                        value: _heightUnit,
                        items: const ['cm', 'in'],
                        onChanged: (val) => setState(() => _heightUnit = val ?? 'cm'),
                      ),
                    ),
                  ]
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      label: 'Weight',
                      icon: Icons.monitor_weight_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      suffix: Text(_weightUnit, style: theme.textTheme.bodySmall),
                      validator: (val) {
                        if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                          return 'Invalid weight';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: _buildDropdownFieldWithoutIcon(
                        value: _weightUnit,
                        items: const ['kg', 'lbs'],
                        onChanged: (val) => setState(() => _weightUnit = val ?? 'kg'),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        const SizedBox(height: 8),
        _buildSectionHeader(theme, 'Cardiovascular & Vitals'),
        if (!_isEditing)
          _buildGlassCard(
            context: context,
            children: [
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
            ],
          )
        else
          _buildGlassCard(
            context: context,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _bpTopController,
                      label: 'BP Systolic (Top)',
                      icon: Icons.favorite_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      placeholder: 'e.g. 120',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _bpBottomController,
                      label: 'BP Diastolic (Bottom)',
                      icon: Icons.heart_broken_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      placeholder: 'e.g. 80',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _bpmController,
                      label: 'Resting Heart Rate',
                      icon: Icons.favorite_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      placeholder: 'e.g. 72',
                      suffix: Text('bpm', style: theme.textTheme.bodySmall),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _oxygenController,
                      label: 'Blood Oxygen (SpO2)',
                      icon: Icons.opacity_rounded,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      placeholder: 'e.g. 98',
                      suffix: Text('%', style: theme.textTheme.bodySmall),
                    ),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 8),
        _buildSectionHeader(theme, 'Habits & Routine Targets'),
        if (!_isEditing)
          _buildGlassCard(
            context: context,
            children: [
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
            ],
          )
        else
          _buildGlassCard(
            context: context,
            children: [
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
                suffix: Text('hrs', style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        const SizedBox(height: 8),
        _buildSectionHeader(theme, 'Medical History'),
        if (!_isEditing)
          _buildGlassCard(
            context: context,
            children: [
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
            ],
          )
        else
          _buildGlassCard(
            context: context,
            children: [
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
    );
  }

  // --- REUSABLE UI BUILDER METHODS ---

  Widget _buildGlassCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8))
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    final customColors = theme.extension<VitalUpColors>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 12.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.7,
          color: customColors?.grayText ?? const Color(0xFF777777),
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final vColors = theme.extension<VitalUpColors>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: vColors?.grayText ?? Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: value.isNotEmpty ? null : theme.disabledColor,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey.withValues(alpha: 0.1),
      height: 1,
      thickness: 1,
      indent: 48,
    );
  }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: enabled ? null : theme.disabledColor,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          suffixIcon: suffix,
          filled: true,
          fillColor: enabled 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
              : theme.disabledColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          filled: true,
          fillColor: theme.disabledColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.25),
            ),
          ),
        ),
        child: Text(
          value.isNotEmpty ? value : 'N/A',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        readOnly: true,
        validator: validator,
        onTap: enabled ? () => _selectDate(context) : null,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: enabled ? null : theme.disabledColor,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          filled: true,
          fillColor: enabled 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
              : theme.disabledColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.25),
            ),
          ),
        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : '');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: displayValue.isEmpty ? null : displayValue,
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          filled: true,
          fillColor: enabled 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
              : theme.disabledColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.25),
            ),
          ),
        ),
        items: items.map<DropdownMenuItem<String>>((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdownFieldWithoutIcon({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : '');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: displayValue.isEmpty ? null : displayValue,
        onChanged: onChanged,
        isExpanded: true, // This prevents RenderFlex overflow in narrow spaces
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8)).withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
          ),
        ),
        items: items.map<DropdownMenuItem<String>>((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(
              val,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }
}
