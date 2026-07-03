import 'package:flutter/material.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class ExtraDetailsPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  const ExtraDetailsPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<ExtraDetailsPage> createState() => _ExtraDetailsPageState();
}

class _ExtraDetailsPageState extends State<ExtraDetailsPage> {
  late String healthConditions;
  late String medicines;
  late String allergies;
  String? smoking;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    healthConditions = state.healthConditions;
    medicines = state.medicines;
    allergies = state.allergies;
    smoking = state.smokes.isEmpty ? null : state.smokes;
  }

  void _saveData() {
    final cubit = context.read<OnboardingCubit>();
    cubit.updateHealthConditions(healthConditions);
    cubit.updateMedicines(medicines);
    cubit.updateAllergies(allergies);
    if (smoking != null) {
      cubit.updateSmoke(smoking!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 9, 
      onBack: () {
        widget.onBack?.call();
      },
      onSkip: () {
        widget.onSkip?.call();
      },
      onNext: () {
        _saveData();
        widget.onNext?.call();
      },
      title: "A little more about you",
      subtitle: "This helps us give you safer and more relevant wellness tips.",
      nextEnabled: true,
      titleBottomSpace: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

            OnboardingTextField(
              label: "Do you have any ongoing health conditions?",
              value: healthConditions,
              onChange: (val) {
                setState(() {
                  healthConditions = val;
                });
                _saveData();
              },
              placeholder: "e.g. Diabetes, asthma, blood pressure",
              maxLength: 200,
            ),
            const SizedBox(height: OnboardingStyle.sectionSpacingMedium),
            
            OnboardingTextField(
              label: "Are you taking any regular medicines?",
              value: medicines,
              onChange: (val) {
                setState(() {
                  medicines = val;
                });
                _saveData();
              },
              placeholder: "e.g. Metformin, insulin, inhaler",
              maxLength: 200,
            ),
            const SizedBox(height: OnboardingStyle.sectionSpacingMedium),
            
            OnboardingTextField(
              label: "Do you have any allergies?",
              value: allergies,
              onChange: (val) {
                setState(() {
                  allergies = val;
                });
                _saveData();
              },
              placeholder: "e.g. food or medicine allergy",
              maxLength: 200,
            ),
            const SizedBox(height: OnboardingStyle.sectionSpacingMedium),
            
            Text(
              "Do you currently smoke?",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: OnboardingStyle.labelFontSize,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6.0),
            
            Row(
              children: [
                _buildOptionButton(
                  text: "No",
                  isSelected: smoking == "No",
                  onClick: () {
                    setState(() => smoking = "No");
                    _saveData();
                  },
                ),
                const SizedBox(width: 12),
                _buildOptionButton(
                  text: "Sometimes",
                  isSelected: smoking == "Sometimes",
                  onClick: () {
                    setState(() => smoking = "Sometimes");
                    _saveData();
                  },
                ),
                const SizedBox(width: 12),
                _buildOptionButton(
                  text: "Often",
                  isSelected: smoking == "Often",
                  onClick: () {
                    setState(() => smoking = "Often");
                    _saveData();
                  },
                ),
              ],
            ),
            const SizedBox(height: OnboardingStyle.sectionSpacingMedium),
          ],
        ),
      );
  }

  Widget _buildOptionButton({
    required String text,
    required bool isSelected,
    required VoidCallback onClick,
  }) {
    const gradientStart = Color.fromRGBO(25, 195, 224, 0.08);
    const gradientEnd = Color.fromRGBO(25, 195, 224, 0.7);
    const selectedBorderColor = Color.fromRGBO(25, 195, 224, 0.27);
    const bgColor = OnboardingColors.fieldBackground;
    const borderColor = OnboardingColors.fieldBorder;

    return Expanded(
      child: InkWell(
        onTap: onClick,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        child: Container(
          height: AppTheme.responsiveInputHeight(context),
          decoration: BoxDecoration(
            color: isSelected ? null : bgColor,
            gradient: isSelected
                ? const LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            border: Border.all(
              color: isSelected ? selectedBorderColor : borderColor,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, 
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
