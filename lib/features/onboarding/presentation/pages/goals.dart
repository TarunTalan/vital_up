import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
          _SectionLabel('Daily Calorie Goal'),
          const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
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
                const SizedBox(width: 12),
                Text('kcal / day',
                    style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.6),
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: OnboardingStyle.sectionSpacingMedium),

          // ── Target Weight ─────────────────────────────────
          _SectionLabel('Target Weight'),
          const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
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
                const SizedBox(width: 12),
                // Unit toggle
                _UnitToggle(
                  selected: targetWeightUnit,
                  options: const ['kg', 'lbs'],
                  onChanged: (u) => setState(() => targetWeightUnit = u),
                ),
              ],
            ),
          ),
          const SizedBox(height: OnboardingStyle.sectionSpacingMedium),

          // ── Goal Duration ─────────────────────────────────
          _SectionLabel('Achieve in'),
          const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _durationOptions.map((months) {
                final selected = months == goalDurationMonths;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => goalDurationMonths = months),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary
                            : OnboardingColors.fieldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : OnboardingColors.fieldBorder,
                        ),
                      ),
                      child: Text(
                        months == 1 ? '1 month' : '$months months',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected
                              ? theme.extension<VitalUpColors>()?.buttonText ??
                                  Colors.black
                              : colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Smart suggestion ──────────────────────────────
          if (note.isNotEmpty) ...
            [
              const SizedBox(height: OnboardingStyle.sectionSpacingMedium),
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
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        letterSpacing: 0.3,
      ),
    );
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : OnboardingColors.fieldBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? colors.primary : OnboardingColors.fieldBorder,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context)
                            .extension<VitalUpColors>()
                            ?.buttonText ??
                        Colors.black
                    : colors.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}


