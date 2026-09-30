import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/diet_plan/presentation/widgets/diet_plan_number_field.dart';

class GoalSetupPage extends StatefulWidget {
  final Map<String, dynamic> preferences;

  const GoalSetupPage({super.key, required this.preferences});

  @override
  State<GoalSetupPage> createState() => _GoalSetupPageState();
}

class _GoalSetupPageState extends State<GoalSetupPage> {
  final _weightController = TextEditingController();
  final _timeframeController = TextEditingController(text: '4'); // default 4 weeks

  @override
  void dispose() {
    _weightController.dispose();
    _timeframeController.dispose();
    super.dispose();
  }

  void _submit() {
    final weight = double.tryParse(_weightController.text);
    final timeframe = int.tryParse(_timeframeController.text);

    if (weight == null || weight <= 0 || timeframe == null || timeframe <= 0) {
      showErrorSnackBar(context, 'Please enter valid positive numbers');
      return;
    }

    context.pushNamed(
      'diet-plan-result',
      extra: {
        'mode': 'goal',
        'preferences': widget.preferences,
        'targetWeight': weight,
        'timeframe': timeframe,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final headingStyle = context.text.headlineSmall;
    return AppScaffold(
      header: const AppPageHeader(title: 'Goal Setup'),
      bottomBar: AppPrimaryButton(label: 'Generate Plan', onTap: _submit),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DietPlanNumberField(
            label: 'What is your target weight?',
            labelStyle: headingStyle,
            controller: _weightController,
            hint: 'e.g. 65',
            suffix: 'kg',
            decimal: true,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          DietPlanNumberField(
            label: 'In how many weeks do you want to achieve this?',
            labelStyle: headingStyle,
            controller: _timeframeController,
            hint: 'e.g. 4',
            suffix: 'weeks',
          ),
        ],
      ),
    );
  }
}
