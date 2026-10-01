import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';

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

  /// Field errors, shown after "Generate Plan" and cleared on edit.
  final Map<TextEditingController, String?> _errors = {};

  @override
  void dispose() {
    _calController.dispose();
    _proController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _clearError(TextEditingController field) {
    if (_errors[field] != null) setState(() => _errors[field] = null);
  }

  void _submit() {
    final cal = int.tryParse(_calController.text);
    final pro = int.tryParse(_proController.text);
    final carb = int.tryParse(_carbController.text);
    final fat = int.tryParse(_fatController.text);

    setState(() {
      _errors
        ..[_calController] =
            cal == null || cal < 1000 ? 'Enter at least 1000 kcal' : null
        ..[_proController] = pro == null ? 'Enter grams of protein' : null
        ..[_carbController] = carb == null ? 'Enter grams of carbs' : null
        ..[_fatController] = fat == null ? 'Enter grams of fat' : null;
    });
    if (cal == null || cal < 1000 || pro == null || carb == null || fat == null) {
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
          AppTextField.integer(
            label: 'Daily Calories',
            hint: 'e.g. 2000',
            suffixText: 'kcal',
            controller: _calController,
            error: _errors[_calController],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(_calController),
          ),
          const SizedBox(height: AppDimens.space16),
          AppTextField.integer(
            label: 'Protein',
            hint: 'e.g. 120',
            suffixText: 'g',
            controller: _proController,
            error: _errors[_proController],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(_proController),
          ),
          const SizedBox(height: AppDimens.space16),
          AppTextField.integer(
            label: 'Carbohydrates',
            hint: 'e.g. 220',
            suffixText: 'g',
            controller: _carbController,
            error: _errors[_carbController],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(_carbController),
          ),
          const SizedBox(height: AppDimens.space16),
          AppTextField.integer(
            label: 'Fats',
            hint: 'e.g. 60',
            suffixText: 'g',
            controller: _fatController,
            error: _errors[_fatController],
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearError(_fatController),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}
