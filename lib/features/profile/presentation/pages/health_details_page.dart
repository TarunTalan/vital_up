import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';
import 'package:vital_up/features/profile/presentation/widgets/health_snapshot_card.dart';
import 'package:vital_up/features/weight/presentation/weight_entry_sheet.dart';

/// Body measurements, vitals, lifestyle and medical history. Each section
/// edits in its own sheet; weight is logged (so Home and the trend see it)
/// and units come from Settings.
class HealthDetailsPage extends StatefulWidget {
  const HealthDetailsPage({super.key});

  @override
  State<HealthDetailsPage> createState() => _HealthDetailsPageState();
}

class _HealthDetailsPageState extends State<HealthDetailsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ProfileCubit>();
      if (cubit.state is ProfileInitial || cubit.state is ProfileError) {
        cubit.loadProfile();
      }
    });
  }

  Future<void> _edit(
    ProfileEntity profile,
    Widget Function(ProfileEntity profile) sheet,
  ) async {
    final cubit = context.read<ProfileCubit>();
    final updated = await showAppBottomSheet<ProfileEntity>(
      context: context,
      builder: (_) => sheet(profile),
    );
    if (updated != null && updated != profile) {
      await cubit.updateProfile(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    const header = AppPageHeader(
      title: 'Health & body',
      subtitle: 'Used for your targets and reports',
    );

    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileSaveSuccess) {
          showSuccessSnackBar(context, 'Health details saved');
        } else if (state is ProfileError) {
          showErrorSnackBar(context, state.message);
        }
      },
      // A failed save is reported, then the profile comes straight back.
      buildWhen: (prev, next) =>
          next is! ProfileError || prev.shownProfile == null,
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final profile = cubit.currentProfile;
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
          body: _HealthBody(
            profile: profile,
            onEdit: (sheet) => _edit(profile, sheet),
          ),
        );
      },
    );
  }
}

class _HealthBody extends StatelessWidget {
  final ProfileEntity profile;
  final void Function(Widget Function(ProfileEntity) sheet) onEdit;

  const _HealthBody({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final heart = context.colors.error;
    final hasBp =
        profile.bloodPressureTop.isNotEmpty &&
        profile.bloodPressureBottom.isNotEmpty;
    final sleepGoal = formatMinutesGoal(
      sl<SleepService>().getGoalMinutes().toDouble(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          'Body',
          actionLabel: 'Edit',
          onAction: () => onEdit((p) => _BodySheet(profile: p)),
        ),
        HealthSnapshotCard(
          profile: profile,
          onLogWeight: () => showWeightEntrySheet(context),
          footer: Row(
            children: [
              AppIconBadge(
                icon: const Icon(Icons.directions_run_rounded),
                color: AppColors.trackWeight,
                size: AppDimens.avatarSmall,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text('Activity level', style: context.text.bodyMedium),
              ),
              Text(
                profile.activity.isEmpty ? 'Not added' : profile.activity,
                style: context.text.bodyMedium?.copyWith(color: v.grayText),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),

        AppListGroup(
          title: 'Vitals',
          actionLabel: 'Edit',
          onAction: () => onEdit((p) => _VitalsSheet(profile: p)),
          children: [
            AppListTile(
              icon: Icons.favorite_rounded,
              iconColor: heart,
              title: 'Blood pressure',
              value: hasBp
                  ? '${profile.bloodPressureTop}/${profile.bloodPressureBottom} mmHg'
                  : 'Not added',
            ),
            AppListTile(
              icon: Icons.monitor_heart_outlined,
              iconColor: heart,
              title: 'Resting heart rate',
              value: profile.bpm.isEmpty ? 'Not added' : '${profile.bpm} bpm',
            ),
            AppListTile(
              icon: Icons.air_rounded,
              title: 'Blood oxygen',
              value: profile.oxygenLevel.isEmpty
                  ? 'Not added'
                  : '${profile.oxygenLevel} %',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sectionGap),

        AppListGroup(
          title: 'Lifestyle',
          actionLabel: 'Edit',
          onAction: () => onEdit((p) => _LifestyleSheet(profile: p)),
          children: [
            AppListTile(
              icon: Icons.smoke_free_rounded,
              iconColor: v.grayText,
              title: 'Smoking',
              value: profile.smokes.isEmpty ? 'Not added' : profile.smokes,
            ),
            AppListTile(
              icon: Icons.bedtime_rounded,
              iconColor: AppColors.trackSleep,
              title: 'Sleep goal',
              subtitle: 'Set in My goals',
              value: sleepGoal,
              onTap: () => context.pushNamed('my-goals'),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sectionGap),

        AppSectionHeader(
          'Medical history',
          actionLabel: 'Edit',
          onAction: () => onEdit((p) => _MedicalSheet(profile: p)),
        ),
        AppCard(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChipList(label: 'Conditions', value: profile.healthConditions),
              Divider(height: AppDimens.space24, color: v.divider),
              _ChipList(label: 'Allergies', value: profile.allergies),
              Divider(height: AppDimens.space24, color: v.divider),
              _ChipList(label: 'Medications', value: profile.medicines),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),

        const AppInfoNote(
          icon: Icons.shield_outlined,
          message: 'Only shared in reports you create.',
        ),
        const SizedBox(height: AppDimens.space12),
        AppSecondaryButton(
          label: 'Create doctor report',
          leadingIcon: Icon(
            Icons.medical_services_outlined,
            size: AppDimens.iconMd,
            color: v.secondaryButtonText,
          ),
          onTap: () => context.pushNamed('health-report'),
        ),
      ],
    );
  }
}

class _ChipList extends StatelessWidget {
  final String label;
  final String value;

  const _ChipList({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final items = splitList(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.bodySmall?.copyWith(color: v.grayText)),
        const SizedBox(height: AppDimens.space8),
        if (items.isEmpty)
          Text(
            'None added',
            style: context.text.bodyMedium?.copyWith(color: v.grayText),
          )
        else
          Wrap(
            spacing: AppDimens.space6,
            runSpacing: AppDimens.space6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space10,
                    vertical: AppDimens.space4,
                  ),
                  decoration: BoxDecoration(
                    color: v.glassFill,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    border: Border.all(color: v.glassBorder!),
                  ),
                  child: Text(item, style: context.text.bodySmall),
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section edit sheets. Each pops the updated profile, or nothing.
// ---------------------------------------------------------------------------

class _SectionSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Widget> Function(BuildContext context) fields;
  final ProfileEntity? Function() onSave;

  const _SectionSheet({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.onSave,
  });

  @override
  State<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends State<_SectionSheet> {
  final _formKey = GlobalKey<FormState>();

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final updated = widget.onSave();
    if (updated != null) Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    // showAppBottomSheet already lifts the sheet above the keyboard.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        AppDimens.sectionGap,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: context.text.headlineSmall),
            const SizedBox(height: AppDimens.space4),
            Text(
              widget.subtitle,
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.space20),
            ...widget.fields(context),
            const SizedBox(height: AppDimens.space8),
            AppPrimaryButton(label: 'Save', onTap: _save),
          ],
        ),
      ),
    );
  }
}

const _fieldGap = SizedBox(height: AppDimens.space16);

Widget _pair(Widget first, Widget second) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: first),
    const SizedBox(width: AppDimens.space12),
    Expanded(child: second),
  ],
);

/// Optional whole number between [min] and [max].
String? Function(String) _range(int min, int max, String name) => (value) {
  if (value.isEmpty) return null;
  final n = int.tryParse(value);
  if (n == null || n < min || n > max) {
    return 'Enter $name between $min and $max';
  }
  return null;
};

class _BodySheet extends StatefulWidget {
  final ProfileEntity profile;

  const _BodySheet({required this.profile});

  @override
  State<_BodySheet> createState() => _BodySheetState();
}

class _BodySheetState extends State<_BodySheet> {
  late final double? _cm = profileHeightCm(widget.profile);
  late final _heightCm = TextEditingController(
    text: _cm == null ? '' : _cm.round().toString(),
  );
  late final int? _inches = _cm == null
      ? null
      : (_cm / CalculateCalorieGoal.cmPerInch).round();
  late final _feet = TextEditingController(text: _initialFeet);
  late final _inch = TextEditingController(text: _initialInch);
  late final String _initialFeet = _inches == null ? '' : '${_inches ~/ 12}';
  late final String _initialInch = _inches == null ? '' : '${_inches % 12}';
  late final String _initialCm = _heightCm.text;

  /// Height in cm from the fields (null while empty).
  double? _enteredCm(bool imperial) {
    if (!imperial) return double.tryParse(_heightCm.text.trim());
    final ft = int.tryParse(_feet.text.trim());
    if (ft == null) return null;
    final inch = int.tryParse(_inch.text.trim()) ?? 0;
    return (ft * 12 + inch) * CalculateCalorieGoal.cmPerInch;
  }

  /// Range check on the whole height, or null when fine or left empty.
  String? _heightError(bool imperial) {
    final empty = imperial
        ? _feet.text.trim().isEmpty && _inch.text.trim().isEmpty
        : _heightCm.text.trim().isEmpty;
    if (empty) return null;
    if (imperial && _feet.text.trim().isEmpty) return 'Enter feet too';
    return ProfileRules.heightError(_enteredCm(imperial));
  }
  late String _activity = widget.profile.activity;

  @override
  void dispose() {
    _heightCm.dispose();
    _feet.dispose();
    _inch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imperial = usesImperialHeight(watchSettings(context));
    final levels = [
      ...activityLevels,
      // Keep an older saved value selectable instead of replacing it.
      if (_activity.isNotEmpty && !activityLevels.contains(_activity))
        _activity,
    ];

    return _SectionSheet(
      title: 'Body',
      subtitle: 'Used to set your calorie and activity targets.',
      fields: (context) => [
        if (imperial)
          _pair(
            AppTextField.integer(
              controller: _feet,
              label: 'Height',
              suffixText: 'ft',
              validator: (value) =>
                  _range(1, 8, 'feet')(value) ?? _heightError(true),
            ),
            AppTextField.integer(
              controller: _inch,
              label: ' ',
              suffixText: 'in',
              validator: _range(0, 11, 'inches'),
            ),
          )
        else
          AppTextField.integer(
            controller: _heightCm,
            label: 'Height',
            prefixIcon: Icons.straighten_rounded,
            suffixText: 'cm',
            validator: (_) => _heightError(false),
          ),
        _fieldGap,
        AppDropdownField<String>(
          label: 'Activity level',
          value: _activity.isEmpty ? null : _activity,
          items: levels,
          itemLabel: (item) => item,
          prefixIcon: Icons.directions_run_rounded,
          hint: 'Choose your typical day',
          onChanged: (value) => setState(() => _activity = value ?? ''),
        ),
        _fieldGap,
        const AppInfoNote(
          message:
              'To change your weight, use Log weight so your trend '
              'stays up to date.',
        ),
        _fieldGap,
      ],
      onSave: () {
        // Untouched height keeps its saved value and unit (a cm height
        // shown in ft/in would otherwise be rounded on every save).
        final heightUnchanged = imperial
            ? _feet.text == _initialFeet && _inch.text == _initialInch
            : _heightCm.text == _initialCm;
        if (heightUnchanged) {
          return widget.profile.copyWith(activity: _activity);
        }
        if (imperial) {
          final ft = _feet.text.trim();
          final inch = _inch.text.trim();
          return widget.profile.copyWith(
            height: ft.isEmpty ? '' : '$ft-${inch.isEmpty ? '0' : inch}',
            heightUnit: ft.isEmpty ? widget.profile.heightUnit : 'ft',
            activity: _activity,
          );
        }
        final cm = _heightCm.text.trim();
        return widget.profile.copyWith(
          height: cm,
          heightUnit: cm.isEmpty ? widget.profile.heightUnit : 'cm',
          activity: _activity,
        );
      },
    );
  }
}

class _VitalsSheet extends StatefulWidget {
  final ProfileEntity profile;

  const _VitalsSheet({required this.profile});

  @override
  State<_VitalsSheet> createState() => _VitalsSheetState();
}

class _VitalsSheetState extends State<_VitalsSheet> {
  late final _top = TextEditingController(
    text: widget.profile.bloodPressureTop,
  );
  late final _bottom = TextEditingController(
    text: widget.profile.bloodPressureBottom,
  );
  late final _bpm = TextEditingController(text: widget.profile.bpm);
  late final _oxygen = TextEditingController(text: widget.profile.oxygenLevel);

  @override
  void dispose() {
    _top.dispose();
    _bottom.dispose();
    _bpm.dispose();
    _oxygen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionSheet(
      title: 'Vitals',
      subtitle: 'Enter your most recent readings.',
      fields: (context) => [
        _pair(
          AppTextField.integer(
            controller: _top,
            label: 'Systolic',
            hint: '120',
            validator: (value) {
              if (value.isEmpty != _bottom.text.trim().isEmpty) {
                return 'Enter both numbers';
              }
              return _range(70, 250, 'systolic')(value);
            },
          ),
          AppTextField.integer(
            controller: _bottom,
            label: 'Diastolic',
            hint: '80',
            validator: (value) {
              if (value.isEmpty != _top.text.trim().isEmpty) {
                return 'Enter both numbers';
              }
              return _range(40, 150, 'diastolic')(value);
            },
          ),
        ),
        _fieldGap,
        AppTextField.integer(
          controller: _bpm,
          label: 'Resting heart rate',
          prefixIcon: Icons.monitor_heart_outlined,
          suffixText: 'bpm',
          validator: _range(30, 220, 'a heart rate'),
        ),
        _fieldGap,
        AppTextField.integer(
          controller: _oxygen,
          label: 'Blood oxygen (SpO2)',
          prefixIcon: Icons.air_rounded,
          suffixText: '%',
          validator: _range(70, 100, 'a reading'),
        ),
        _fieldGap,
        const AppInfoNote(
          message: 'A normal resting blood pressure is below 120/80 mmHg.',
        ),
        _fieldGap,
      ],
      onSave: () => widget.profile.copyWith(
        bloodPressureTop: _top.text.trim(),
        bloodPressureBottom: _bottom.text.trim(),
        bpm: _bpm.text.trim(),
        oxygenLevel: _oxygen.text.trim(),
      ),
    );
  }
}

class _LifestyleSheet extends StatefulWidget {
  final ProfileEntity profile;

  const _LifestyleSheet({required this.profile});

  @override
  State<_LifestyleSheet> createState() => _LifestyleSheetState();
}

class _LifestyleSheetState extends State<_LifestyleSheet> {
  late String _smokes = widget.profile.smokes;

  @override
  Widget build(BuildContext context) {
    return _SectionSheet(
      title: 'Lifestyle',
      subtitle: 'Helps Vita tailor its advice.',
      fields: (context) => [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.inputLabelGap),
          child: Text('Do you smoke?', style: context.text.titleSmall),
        ),
        AppSegmentedControl<String>(
          values: smokerOptions,
          selected: _smokes,
          label: (value) => value,
          onChanged: (value) => setState(() => _smokes = value),
        ),
        _fieldGap,
      ],
      onSave: () => widget.profile.copyWith(smokes: _smokes),
    );
  }
}

class _MedicalSheet extends StatefulWidget {
  final ProfileEntity profile;

  const _MedicalSheet({required this.profile});

  @override
  State<_MedicalSheet> createState() => _MedicalSheetState();
}

class _MedicalSheetState extends State<_MedicalSheet> {
  late final _conditions = TextEditingController(
    text: widget.profile.healthConditions,
  );
  late final _allergies = TextEditingController(text: widget.profile.allergies);
  late final _medicines = TextEditingController(text: widget.profile.medicines);

  @override
  void dispose() {
    _conditions.dispose();
    _allergies.dispose();
    _medicines.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => AppTextField(
    controller: controller,
    label: label,
    hint: 'Separate items with commas',
    prefixIcon: icon,
    textCapitalization: TextCapitalization.sentences,
    maxLength: InputLimits.note,
  );

  @override
  Widget build(BuildContext context) {
    return _SectionSheet(
      title: 'Medical history',
      subtitle: 'Only shared in reports you create.',
      fields: (context) => [
        _field(_conditions, 'Conditions', Icons.medical_services_outlined),
        _fieldGap,
        _field(_allergies, 'Allergies', Icons.warning_amber_rounded),
        _fieldGap,
        _field(_medicines, 'Medications', Icons.medication_rounded),
        _fieldGap,
      ],
      onSave: () => widget.profile.copyWith(
        healthConditions: ProfileRules.cleanNote(_conditions.text),
        allergies: ProfileRules.cleanNote(_allergies.text),
        medicines: ProfileRules.cleanNote(_medicines.text),
      ),
    );
  }
}
