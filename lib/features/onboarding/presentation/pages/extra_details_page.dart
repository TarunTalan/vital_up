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
      title: "Any extra details?",
      subtitle: "This helps us tailor your experience.",
      nextEnabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

            OnboardingTextField(
              label: "Any ongoing health conditions?",
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
            const SizedBox(height: AppDimens.sectionGap),
            
            OnboardingTextField(
              label: "Any regular medicines?",
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
            const SizedBox(height: AppDimens.sectionGap),
            
            OnboardingTextField(
              label: "Any allergies?",
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
            const SizedBox(height: AppDimens.sectionGap),
            
            Text("Do you smoke?", style: context.text.titleSmall),
            const SizedBox(height: AppDimens.inputLabelGap),
            
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
                const SizedBox(width: AppDimens.space8),
                _buildOptionButton(
                  text: "Sometimes",
                  isSelected: smoking == "Sometimes",
                  onClick: () {
                    setState(() => smoking = "Sometimes");
                    _saveData();
                  },
                ),
                const SizedBox(width: AppDimens.space8),
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
            const SizedBox(height: AppDimens.sectionGap),
          ],
        ),
      );
  }

  Widget _buildOptionButton({
    required String text,
    required bool isSelected,
    required VoidCallback onClick,
  }) {
    return Expanded(
      child: OnboardingOptionTile(
        label: text,
        isSelected: isSelected,
        minHeight: AppDimens.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.space8),
        labelStyle: context.text.bodyMedium,
        onTap: onClick,
      ),
    );
  }
}
