import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/core/utils/input_rules.dart';
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

  // Daily ranges a plan can be built for.
  static const _minCalories = 1000;
  static const _maxCalories = 6000;
  static const _maxProtein = 400;
  static const _maxCarbs = 900;
  static const _maxFat = 300;

  int? _read(TextEditingController c, int min, int max) =>
      parseNumberInRange(c.text, min: min, max: max)?.round();

  void _submit() {
    final cal = _read(_calController, _minCalories, _maxCalories);
    final pro = _read(_proController, 0, _maxProtein);
    final carb = _read(_carbController, 0, _maxCarbs);
    final fat = _read(_fatController, 0, _maxFat);

    // Macros must roughly fit the calories (4 / 4 / 9 kcal per gram).
    final macroKcal = (pro ?? 0) * 4 + (carb ?? 0) * 4 + (fat ?? 0) * 9;
    final macrosTooHigh = cal != null && pro != null && carb != null && fat != null && macroKcal > cal * 1.25;

    setState(() {
      _errors
        ..[_calController] = cal == null
            ? 'Enter $_minCalories to $_maxCalories kcal'
            : macrosTooHigh
                ? 'Your macros add up to $macroKcal kcal. Lower them.'
                : null
        ..[_proController] = pro == null ? 'Enter 0 to $_maxProtein g' : null
        ..[_carbController] = carb == null ? 'Enter 0 to $_maxCarbs g' : null
        ..[_fatController] = fat == null ? 'Enter 0 to $_maxFat g' : null;
    });
    if (cal == null || pro == null || carb == null || fat == null || macrosTooHigh) {
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
