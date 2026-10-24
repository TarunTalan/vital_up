import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import 'package:vital_up/core/widgets/tracker/goal_controls.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';
import 'package:vital_up/features/profile/presentation/widgets/health_snapshot_card.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
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
    if (!mounted) return;
    setState(() {});
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
            body: state is ProfileError
                ? LoadErrorView(
                    onRetry: () => cubit.loadProfile(forceRefresh: true),
                  )
                : const Center(child: VitalUpLoader()),
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

  /// The Body sheet starts its weight scale at the latest weigh-in (else
  /// the profile's weight), in the unit set in Settings.
  Future<void> _editBody(BuildContext context) async {
    final service = sl<WeightService>();
    final unit = await service.unit();
    final latest = await service.latest();
    if (!context.mounted) return;
    onEdit(
      (p) => _BodySheet(
        profile: p,
        weightUnit: unit,
        weightKg: latest?.weightKg ?? profileWeightKg(p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final heart = context.colors.error;
    final hasBp =
        profile.bloodPressureTop.isNotEmpty &&
        profile.bloodPressureBottom.isNotEmpty;
    final sleepGoal = switch (sl<SleepService>().getGoalMinutes()) {
      null => 'No goal',
      final minutes => formatMinutesGoal(minutes.toDouble()),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          'Body',
          actionLabel: 'Edit',
          onAction: () => _editBody(context),
        ),
        HealthSnapshotCard(
          profile: profile,
          onLogWeight: () => showWeightEntrySheet(context),
          footer: Padding(
            padding: const EdgeInsets.only(top: AppDimens.space12),
            child: Row(
              children: [
                AppIconBadge(
                  icon: SvgPicture.asset(
                    'assets/icons/trackers/activity.svg',
                    width: AppDimens.iconXs,
                    height: AppDimens.iconXs,
                    colorFilter: ColorFilter.mode(
                      AppColors.trackWeight,
                      BlendMode.srcIn,
                    ),
                  ),
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
              icon: Icons.monitor_heart_rounded,
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
              value: sleepGoal,
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
          icon: Icons.shield_rounded,
          message: 'Only shared in reports you create.',
        ),
        const SizedBox(height: AppDimens.space12),
        AppSecondaryButton(
          label: 'Create doctor report',
          leadingIcon: Icon(
            Icons.medical_services_rounded,
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

  /// The edited profile to save, or null to stay open (shows its error).
  final FutureOr<ProfileEntity?> Function() onSave;

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
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final updated = await widget.onSave();
    if (!mounted) return;
    if (updated != null) {
      Navigator.of(context).pop(updated);
    } else {
      setState(() => _saving = false);
    }
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
            AppPrimaryButton(label: 'Save', isLoading: _saving, onTap: _save),
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
  final WeightUnit weightUnit;

  /// Where the weight scale starts (latest weigh-in); null when none.
  final double? weightKg;

  const _BodySheet({
    required this.profile,
    required this.weightUnit,
    this.weightKg,
  });

  @override
  State<_BodySheet> createState() => _BodySheetState();
}

/// Height and weight on the same scales as onboarding and Log weight. A
/// scale left untouched saves nothing (a height saved in cm and shown in
/// ft / in would otherwise be rounded on every save); a new weight is
/// logged as today's weigh-in so Home and the trend see it.
class _BodySheetState extends State<_BodySheet> {
  static const _cmPerInch = CalculateCalorieGoal.cmPerInch;

  /// The feet scale runs in whole inches from 2 ft (labels on whole feet).
  static const _minInches = 24;
  static final _maxInches = (InputLimits.heightCmMax / _cmPerInch).floor();

  /// Where the scales start without a saved value.
  static const _typicalCm = 170.0;
  static const _typicalKg = 70.0;

  late final double? _savedCm = profileHeightCm(widget.profile);
  late double _cm = _savedCm ?? _typicalCm;
  bool _heightTouched = false;

  WeightUnit get _unit => widget.weightUnit;

  /// The picked weight in [_unit], one decimal.
  late double _weight = double.parse(
    _unit
        .fromKg(widget.weightKg ?? _typicalKg)
        .clamp(_unit.minValue.toDouble(), _unit.maxValue.toDouble())
        .toStringAsFixed(1),
  );
  bool _weightTouched = false;

  /// Which measure the scale edits (height first).
  bool _editingWeight = false;
  String? _weightError;

  late String _activity = widget.profile.activity;

  int get _inches => (_cm / _cmPerInch).round().clamp(_minInches, _maxInches);

  Future<ProfileEntity?> _save(bool feet) async {
    var profile = widget.profile.copyWith(activity: _activity);
    if (_heightTouched) {
      profile = feet
          ? profile.copyWith(
              height: '${_inches ~/ 12}-${_inches % 12}',
              heightUnit: 'ft',
            )
          : profile.copyWith(height: '${_cm.round()}', heightUnit: 'cm');
    }
    if (_weightTouched) {
      final kg = _unit.toKg(_weight);
      String? error;
      try {
        error = await sl<WeightService>().add(kg);
      } catch (e) {
        debugPrint('Weight not saved: $e');
        error = "Couldn't save your weight. Try again.";
      }
      if (error != null) {
        if (mounted) setState(() => _weightError = error);
        return null;
      }
      // The figure WeightService writes to the profile too, so whichever
      // save lands last, the profile keeps the new weight.
      final profileUnit = WeightUnit.fromCode(widget.profile.weightUnit);
      profile = profile.copyWith(
        weight: profileUnit.fromKg(kg).toStringAsFixed(1),
        weightUnit: profileUnit.label,
      );
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    final feet = usesImperialHeight(watchSettings(context));
    final levels = [
      ...activityLevels,
      // Keep an older saved value selectable instead of replacing it.
      if (_activity.isNotEmpty && !activityLevels.contains(_activity))
        _activity,
    ];
    final height = feet
        ? '${_inches ~/ 12} ft ${_inches % 12} in'
        : '${_cm.round()} cm';
    final weight = '${_weight.toStringAsFixed(1)} ${_unit.label}';
    final heightAdded = _savedCm != null || _heightTouched;
    final weightAdded = widget.weightKg != null || _weightTouched;
    final added = _editingWeight ? weightAdded : heightAdded;
    final note = !added
        ? 'Not added yet. Drag the scale to set it.'
        : _editingWeight && _weightTouched
        ? "Saved as today's weigh-in."
        : null;

    return _SectionSheet(
      title: 'Body',
      subtitle: 'Used to set your calorie and activity targets.',
      fields: (context) => [
        Row(
          children: [
            Expanded(
              child: _MeasureTile(
                label: 'Height',
                figure: heightAdded ? height : 'Not added',
                selected: !_editingWeight,
                onTap: () => setState(() => _editingWeight = false),
              ),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: _MeasureTile(
                label: 'Weight',
                figure: weightAdded ? weight : 'Not added',
                selected: _editingWeight,
                onTap: () => setState(() => _editingWeight = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space16),
        // One scale for the selected measure.
        if (_editingWeight)
          ValueRuler(
            key: const ValueKey('kg'),
            value: _weight,
            min: _unit.minValue.toDouble(),
            max: _unit.maxValue.toDouble(),
            color: AppColors.trackWeight,
            semanticValue: (v) => '${v.toStringAsFixed(1)} ${_unit.label}',
            onChanged: (v) => setState(() {
              _weight = v;
              _weightTouched = true;
              _weightError = null;
            }),
          )
        else if (feet)
          ValueRuler(
            key: const ValueKey('ft'),
            value: _inches.toDouble(),
            min: _minInches.toDouble(),
            max: _maxInches.toDouble(),
            step: 1,
            majorEvery: 12,
            midEvery: 6,
            color: context.colors.primary,
            labelFor: (v) => '${v.round() ~/ 12} ft',
            semanticValue: (v) =>
                '${v.round() ~/ 12} feet ${v.round() % 12} inches',
            onChanged: (v) => setState(() {
              _cm = v * _cmPerInch;
              _heightTouched = true;
            }),
          )
        else
          ValueRuler(
            key: const ValueKey('cm'),
            value: _cm.roundToDouble().clamp(
              InputLimits.heightCmMin,
              InputLimits.heightCmMax,
            ),
            min: InputLimits.heightCmMin,
            max: InputLimits.heightCmMax,
            step: 1,
            color: context.colors.primary,
            semanticValue: (v) => '${v.round()} centimetres',
            onChanged: (v) => setState(() {
              _cm = v;
              _heightTouched = true;
            }),
          ),
        if (_weightError case final error?) ...[
          const SizedBox(height: AppDimens.space8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),
        ] else if (note != null) ...[
          const SizedBox(height: AppDimens.space8),
          Text(
            note,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
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
      ],
      onSave: () => _save(feet),
    );
  }
}

/// Height or weight with its value; the selected one is on the scale.
/// Picks something, so no chevron (like the other choice cards).
class _MeasureTile extends StatelessWidget {
  final String label;
  final String figure;
  final bool selected;
  final VoidCallback onTap;

  const _MeasureTile({
    required this.label,
    required this.figure,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        width: double.infinity,
        padding: AppDimens.cardPaddingCompact,
        borderColor: selected ? context.colors.primary : null,
        tint: selected ? context.vColors.primaryFill : null,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.bodySmall?.copyWith(color: grey)),
            const SizedBox(height: AppDimens.space4),
            FitText(
              figure,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
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
          prefixIcon: Icons.monitor_heart_rounded,
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

  /// Null when the user has no sleep goal; saving this sheet only sets
  /// one if they moved it.
  final int? _savedGoal = sl<SleepService>().getGoalMinutes();
  late int _sleepMinutes = _savedGoal ?? SleepService.defaultGoalMinutes;
  bool _goalChanged = false;

  void _setSleepGoal(int minutes) {
    _goalChanged = true;
    final clamped = minutes.clamp(
      InputLimits.sleepGoalMinMin,
      InputLimits.sleepGoalMinMax,
    );
    if (clamped != _sleepMinutes) {
      HapticFeedback.lightImpact();
      setState(() => _sleepMinutes = clamped);
    }
  }

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
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.inputLabelGap),
          child: Text('Nightly sleep goal', style: context.text.titleSmall),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space12,
            vertical: AppDimens.space12,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Decrease sleep goal',
                    onPressed: _sleepMinutes > InputLimits.sleepGoalMinMin
                        ? () => _setSleepGoal(_sleepMinutes - 30)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMinutesGoal(_sleepMinutes.toDouble()),
                          textAlign: TextAlign.center,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.trackSleep,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space2),
                        Text(
                          'Recommended: 7–9 hrs',
                          style: context.text.bodySmall?.copyWith(
                            color: context.vColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Increase sleep goal',
                    onPressed: _sleepMinutes < InputLimits.sleepGoalMinMax
                        ? () => _setSleepGoal(_sleepMinutes + 30)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space8),
              SleepGoalDial(
                value: _sleepMinutes.toDouble().clamp(
                  InputLimits.sleepGoalMinMin.toDouble(),
                  InputLimits.sleepGoalMinMax.toDouble(),
                ),
                min: InputLimits.sleepGoalMinMin.toDouble(),
                max: InputLimits.sleepGoalMinMax.toDouble(),
                step: 30,
                // The dial gives its own sound and vibration.
                onChanged: (v) => setState(() {
                  _goalChanged = true;
                  _sleepMinutes = v.round();
                }),
              ),
            ],
          ),
        ),
        _fieldGap,
      ],
      onSave: () {
        if (_savedGoal == null && !_goalChanged) {
          return widget.profile.copyWith(smokes: _smokes);
        }
        unawaited(sl<SleepService>().setGoalMinutes(_sleepMinutes));
        return widget.profile.copyWith(
          smokes: _smokes,
          sleep: formatMinutesGoal(_sleepMinutes.toDouble()),
        );
      },
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
        _field(_conditions, 'Conditions', Icons.medical_services_rounded),
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
