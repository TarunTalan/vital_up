import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid macros (Calories must be >= 1000)')),
      );
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

  Widget _buildField(String label, String suffix, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manual Target'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildField('Daily Calories', 'kcal', _calController),
                      _buildField('Protein', 'g', _proController),
                      _buildField('Carbohydrates', 'g', _carbController),
                      _buildField('Fats', 'g', _fatController),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: customColors?.buttonText,
                  ),
                  child: const Text('Generate Plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
