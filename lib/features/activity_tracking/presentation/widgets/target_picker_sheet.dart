import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_target_rules.dart';

/// Bottom sheet for selecting a workout target (distance or calories).
/// Pops `(type, value)` on save, `(WorkoutTargetType.none, 0)` on Clear,
/// or null when dismissed.
class TargetPickerSheet extends StatefulWidget {
  final WorkoutPrefs current;
  final DistanceUnit distanceUnit;

  const TargetPickerSheet({
    super.key,
    required this.current,
    required this.distanceUnit,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkoutPrefs current,
    required DistanceUnit distanceUnit,
    required WorkoutPrefsNotifier notifier,
  }) async {
    await showAppBottomSheet<(WorkoutTargetType, double)?>(
      context: context,
      builder: (_) =>
          TargetPickerSheet(current: current, distanceUnit: distanceUnit),
    ).then((result) {
      if (result == null) return;
      final (WorkoutTargetType type, double val) = result;
      if (type == WorkoutTargetType.none) {
        notifier.clearTarget();
      } else {
        notifier.setTarget(type, val);
      }
    });
  }

  @override
  State<TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<TargetPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _distCtrl = TextEditingController();
  final _calCtrl = TextEditingController();

  /// Shown on the active tab's field when "Set Target" has no value.
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_error != null) setState(() => _error = null);
      });

    // Pre-fill existing values
    if (widget.current.targetType == WorkoutTargetType.distance) {
      final displayVal = widget.distanceUnit == DistanceUnit.miles
          ? widget.current.targetValue / ActivityTargetLimits.kmPerMile
          : widget.current.targetValue;
      _distCtrl.text = displayVal.toStringAsFixed(1);
      _tabs.animateTo(0);
    } else if (widget.current.targetType == WorkoutTargetType.calories) {
      _calCtrl.text = widget.current.targetValue.toStringAsFixed(0);
      _tabs.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _distCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  void _confirm(WorkoutTargetType type) {
    final result = parseActivityTarget(
      type,
      type == WorkoutTargetType.distance ? _distCtrl.text : _calCtrl.text,
      widget.distanceUnit,
    );
    final value = result.value;
    if (value == null) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop((type, value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final distUnitLabel = widget.distanceUnit.label.toUpperCase();
    final fieldHeight =
        MediaQuery.textScalerOf(context).scale(AppDimens.inputHeight) +
        AppDimens.space16;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.sectionGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Target', style: context.text.headlineSmall),
            const SizedBox(height: AppDimens.space16),

            // Segmented tabs — Figma Move/Rest/Fuel/Vitals style.
            Container(
              padding: const EdgeInsets.all(AppDimens.space4),
              decoration: BoxDecoration(
                color: v.glassFill,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(color: v.glassBorder!),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  boxShadow: AppShadows.segment,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: v.buttonText,
                unselectedLabelColor: v.grayText,
                labelStyle: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    height: AppDimens.segmentHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Distance ($distUnitLabel)'),
                    ),
                  ),
                  const Tab(
                    height: AppDimens.segmentHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Calories (kcal)'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space20),

            AnimatedContainer(
              duration: AppDurations.medium,
              // Room for the error line under the field.
              height: fieldHeight +
                  (_error == null
                      ? 0
                      : MediaQuery.textScalerOf(context)
                          .scale(AppDimens.space32)),
              child: TabBarView(
                controller: _tabs,
                children: [
                  _NumberField(
                    controller: _distCtrl,
                    hint: 'e.g. 5.0',
                    suffix: distUnitLabel,
                    error: _error,
                    onChanged: _clearError,
                  ),
                  _NumberField(
                    controller: _calCtrl,
                    hint: 'e.g. 500',
                    suffix: 'kcal',
                    error: _error,
                    onChanged: _clearError,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space8),

            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Clear',
                    // Null would read as "dismissed" and keep the target.
                    onTap: () =>
                        Navigator.of(context).pop((WorkoutTargetType.none, 0.0)),
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Set Target',
                    onTap: () {
                      final type = _tabs.index == 0
                          ? WorkoutTargetType.distance
                          : WorkoutTargetType.calories;
                      _confirm(type);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final String? error;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: AppTextField.decimal(
        controller: controller,
        hint: hint,
        suffixText: suffix,
        error: error,
        onChanged: onChanged,
      ),
    );
  }
}
