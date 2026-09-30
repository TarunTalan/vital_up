import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/presentation/widgets/diet_plan_number_field.dart';

class ManualTargetPage extends StatefulWidget {
  final Map<String, dynamic> preferences;

  const ManualTargetPage({super.key, required this.preferences});

  @override
  State<ManualTargetPage> createState() => _ManualTargetPageState();
}

class _ManualTargetPageState extends State<ManualTargetPage> {
  final _calController = TextEditingController();
  final _proController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void dispose() {
    _calController.dispose();
    _proController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _submit() {
    final cal = int.tryParse(_calController.text);
    final pro = int.tryParse(_proController.text);
    final carb = int.tryParse(_carbController.text);
    final fat = int.tryParse(_fatController.text);

    if (cal == null || cal < 1000 || pro == null || carb == null || fat == null) {
      showErrorSnackBar(context, 'Please enter valid macros (Calories must be >= 1000)');
      return;
    }

    final target = NutritionTarget(calories: cal, protein: pro, carbs: carb, fat: fat);

    context.pushNamed(
      'diet-plan-result',
      extra: {
        'mode': 'manual',
        'preferences': widget.preferences,
        'target': target,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'Manual Target'),
      bottomBar: AppPrimaryButton(label: 'Generate Plan', onTap: _submit),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DietPlanNumberField(label: 'Daily Calories', suffix: 'kcal', controller: _calController),
          const SizedBox(height: AppDimens.space16),
          DietPlanNumberField(label: 'Protein', suffix: 'g', controller: _proController),
          const SizedBox(height: AppDimens.space16),
          DietPlanNumberField(label: 'Carbohydrates', suffix: 'g', controller: _carbController),
          const SizedBox(height: AppDimens.space16),
          DietPlanNumberField(label: 'Fats', suffix: 'g', controller: _fatController),
        ],
      ),
    );
  }
}
