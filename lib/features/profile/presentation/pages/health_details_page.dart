import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';

class HealthDetailsPage extends StatefulWidget {
  const HealthDetailsPage({super.key});

  @override
  State<HealthDetailsPage> createState() => _HealthDetailsPageState();
}

class _HealthDetailsPageState extends State<HealthDetailsPage> {
  final _formKey = GlobalKey<FormState>();

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

  String _weightUnit = 'kg';
  String _heightUnit = 'cm';
  String _activity = '';
  String _smokes = '';

  bool _isEditing = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
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

    _setupListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ProfileCubit>();
      if (cubit.state is ProfileInitial || cubit.state is ProfileError) {
        cubit.loadProfile();
      } else if (cubit.state is ProfileLoaded) {
        _populateFields((cubit.state as ProfileLoaded).profile);
      }
    });
  }

  void _setupListeners() {
    void markDirty() {
      if (!_isDirty) setState(() => _isDirty = true);
    }
    _weightController.addListener(markDirty);
    _heightController.addListener(markDirty);
    _bpTopController.addListener(markDirty);
    _bpBottomController.addListener(markDirty);
    _bpmController.addListener(markDirty);
    _sleepController.addListener(markDirty);
    _oxygenController.addListener(markDirty);
    _conditionsController.addListener(markDirty);
    _allergiesController.addListener(markDirty);
    _medicinesController.addListener(markDirty);
  }

  void _populateFields(ProfileEntity profile) {
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

    _weightUnit = profile.weightUnit.isEmpty ? 'kg' : profile.weightUnit;
    _heightUnit = profile.heightUnit.isEmpty ? 'cm' : profile.heightUnit;
    _activity = profile.activity;
    _smokes = profile.smokes;
    _isDirty = false;
  }

  @override
  void dispose() {
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

  void _saveProfile(ProfileEntity originalProfile) {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = originalProfile.copyWith(
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
        if (state is ProfileSaveSuccess) {
          _populateFields(state.updatedProfile);
          setState(() {
            _isEditing = false;
            _isDirty = false;
          });
          showSuccessSnackBar(context, 'Health details updated successfully!');
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
        }

        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('Profile not available')),
          );
        }

        final isSaving = state is ProfileSaving;

        return AppScaffold(
          header: AppPageHeader(
            title: 'Health & Body',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildHeaderActions(profile, isSaving),
            ),
          ),
          body: Form(
            key: _formKey,
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
                                          suffix: Text(_heightUnit, style: context.text.bodySmall?.copyWith(color: context.vColors.grayText)),
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
                                          onChanged: (val) {
                                            setState(() {
                                              _heightUnit = val ?? 'cm';
                                              _isDirty = true;
                                            });
                                          },
                                        ),
                                      ),
                                      _buildValueWithUnit(
                                        field: _buildTextField(
                                          controller: _weightController,
                                          label: 'Weight',
                                          icon: Icons.monitor_weight_rounded,
                                          enabled: _isEditing,
                                          keyboardType: TextInputType.number,
                                          suffix: Text(_weightUnit, style: context.text.bodySmall?.copyWith(color: context.vColors.grayText)),
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
                                          onChanged: (val) {
                                            setState(() {
                                              _weightUnit = val ?? 'kg';
                                              _isDirty = true;
                                            });
                                          },
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
                                          suffix: Text('bpm', style: context.text.bodySmall?.copyWith(color: context.vColors.grayText)),
                                        ),
                                        _buildTextField(
                                          controller: _oxygenController,
                                          label: 'Blood Oxygen (SpO2)',
                                          icon: Icons.opacity_rounded,
                                          enabled: _isEditing,
                                          keyboardType: TextInputType.number,
                                          placeholder: 'e.g. 98',
                                          suffix: Text('%', style: context.text.bodySmall?.copyWith(color: context.vColors.grayText)),
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
                                      _buildDivider(),
                                      _buildProfileRow(
                                        icon: Icons.smoking_rooms_rounded,
                                        label: 'Smoker Status',
                                        value: profile.smokes,
                                      ),
                                    ]
                                  : [
                                      _buildDropdownField(
                                        label: 'Activity Level',
                                        value: _activity,
                                        icon: Icons.directions_run_rounded,
                                        enabled: _isEditing,
                                        items: const ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'],
                                        onChanged: (val) {
                                          setState(() {
                                            _activity = val ?? '';
                                            _isDirty = true;
                                          });
                                        },
                                      ),
                                      _buildTextField(
                                        controller: _sleepController,
                                        label: 'Daily Sleep Target',
                                        icon: Icons.bedtime_rounded,
                                        enabled: _isEditing,
                                        keyboardType: TextInputType.number,
                                        placeholder: 'e.g. 8',
                                        suffix: Text('hrs', style: context.text.bodySmall?.copyWith(color: context.vColors.grayText)),
                                      ),
                                      _buildDropdownField(
                                        label: 'Smoker Status',
                                        value: _smokes,
                                        icon: Icons.smoking_rooms_rounded,
                                        enabled: _isEditing,
                                        items: const ['No', 'Yes', 'Occasionally'],
                                        onChanged: (val) {
                                          setState(() {
                                            _smokes = val ?? '';
                                            _isDirty = true;
                                          });
                                        },
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
                            const SizedBox(height: AppDimens.space32),
                            if (_isEditing && _isDirty)
                              AppPrimaryButton(
                                label: 'Save Changes',
                                isLoading: isSaving,
                                onTap: () => _saveProfile(profile!),
                              ),
              ],
            ),
          ),
        );
            },
          );
  }

  List<Widget> _buildHeaderActions(ProfileEntity profile, bool isSaving) {
    if (!_isEditing) {
      return [
        AppHeaderAction(
          icon: SvgPicture.asset(
            'assets/icons/edit.svg',
            width: AppDimens.iconMd,
            height: AppDimens.iconMd,
            colorFilter: ColorFilter.mode(context.colors.onSurface, BlendMode.srcIn),
          ),
          onTap: () => setState(() => _isEditing = true),
          tooltip: 'Edit Health Details',
        ),
        const SizedBox(width: AppDimens.space12),
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
        const SizedBox(width: AppDimens.space12),
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
      if (_isDirty) ...[
        const SizedBox(width: AppDimens.space8),
        AppHeaderAction(
          icon: const Icon(Icons.check_rounded),
          onTap: () => _saveProfile(profile),
          tooltip: 'Save Details',
        ),
      ],
      const SizedBox(width: AppDimens.space12),
    ];
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
