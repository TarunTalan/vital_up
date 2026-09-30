import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class GoalsPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const GoalsPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  int? calorieGoal;
  double? targetWeight;
  String targetWeightUnit = 'kg';
  int goalDurationMonths = 3;

  static const _durationOptions = [1, 2, 3, 6, 12];

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    // Pre-fill from saved state
    calorieGoal = state.calorieGoal.isNotEmpty
        ? int.tryParse(state.calorieGoal)
        : _suggestedCalories(state.weight, state.weightUnit);
    targetWeight = state.targetWeight.isNotEmpty
        ? double.tryParse(state.targetWeight)
        : null;
    targetWeightUnit = state.targetWeightUnit.isNotEmpty
        ? state.targetWeightUnit
        : 'kg';
    goalDurationMonths = int.tryParse(state.goalDurationMonths) ?? 3;
  }

  int? _suggestedCalories(String weightStr, String unit) {
    final w = double.tryParse(weightStr);
    if (w == null) return null;
    final kg = unit == 'lbs' ? w * 0.453592 : w;
    // Simple Harris-Benedict estimate (sedentary, approximate)
    return (kg * 24 * 1.2).round();
  }

  String _suggestionNote() {
    final state = context.read<OnboardingCubit>().state;
    final currentW = double.tryParse(state.weight);
    final targetW = targetWeight;
    if (currentW == null || targetW == null) return '';
    final diff = (currentW - targetW).abs();
    final kgPerMonth = diff / goalDurationMonths;
    final action = currentW > targetW ? 'lose' : 'gain';
    return 'Based on your current weight, aim to $action ~${kgPerMonth.toStringAsFixed(1)} kg/month to reach your target in $goalDurationMonths months.';
  }

  @override
  Widget build(BuildContext context) {
    final note = _suggestionNote();

    return OnboardingLayout(
      step: 6,
      onBack: widget.onBack ?? () {},
      onSkip: widget.onSkip ?? () {},
      onNext: () {
        context.read<OnboardingCubit>().updateGoals(
          calorieGoal: calorieGoal?.toString() ?? '',
          targetWeight: targetWeight?.toString() ?? '',
          targetWeightUnit: targetWeightUnit,
          goalDurationMonths: goalDurationMonths.toString(),
        );
        widget.onNext?.call();
      },
      title: 'Set Your Goals 🎯',
      subtitle: 'We\'ll use this to personalise your nutrition plan.',
      nextEnabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Calorie Goal ──────────────────────────────────
          const _SectionLabel('Daily Calorie Goal'),
          const SizedBox(height: AppDimens.inputLabelGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                OnboardingNumberField<int>(
                  value: calorieGoal,
                  min: 800,
                  max: 5000,
                  onValueChange: (v) => setState(() => calorieGoal = v),
                ),
                const SizedBox(width: AppDimens.space12),
                Text(
                  'kcal / day',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.vColors.grayText),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sectionGap),

          // ── Target Weight ─────────────────────────────────
          const _SectionLabel('Target Weight'),
          const SizedBox(height: AppDimens.inputLabelGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                OnboardingNumberField<double>(
                  value: targetWeight,
                  min: 30,
                  max: 250,
                  onValueChange: (v) => setState(() => targetWeight = v),
                ),
                const SizedBox(width: AppDimens.space12),
                _UnitToggle(
                  selected: targetWeightUnit,
                  options: const ['kg', 'lbs'],
                  onChanged: (u) => setState(() => targetWeightUnit = u),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sectionGap),

          // ── Goal Duration ─────────────────────────────────
          const _SectionLabel('Achieve in'),
          const SizedBox(height: AppDimens.inputLabelGap),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: _durationOptions.map((months) {
              return OnboardingOptionTile(
                label: months == 1 ? '1 month' : '$months months',
                isSelected: months == goalDurationMonths,
                minHeight: AppDimens.buttonHeight,
                radius: AppDimens.radiusButton,
                padding: AppDimens.buttonPadding,
                labelStyle: context.text.bodyMedium,
                expand: false,
                onTap: () => setState(() => goalDurationMonths = months),
              );
            }).toList(),
          ),

          // ── Smart suggestion ──────────────────────────────
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppDimens.sectionGap),
            NoteRow(text: note),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.text.titleSmall);
  }
}

class _UnitToggle extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _UnitToggle({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        return Padding(
          padding: const EdgeInsets.only(right: AppDimens.space6),
          child: OnboardingOptionTile(
            label: opt,
            isSelected: opt == selected,
            minHeight: AppDimens.buttonHeight,
            radius: AppDimens.radiusButton,
            padding: AppDimens.buttonPadding,
            labelStyle: context.text.bodyMedium,
            expand: false,
            onTap: () => onChanged(opt),
          ),
        );
      }).toList(),
    );
  }
}
