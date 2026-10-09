import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';

class GoalSetupPage extends StatefulWidget {
  final Map<String, dynamic> preferences;

  const GoalSetupPage({super.key, required this.preferences});

  @override
  State<GoalSetupPage> createState() => _GoalSetupPageState();
}

class _GoalSetupPageState extends State<GoalSetupPage> {
  final _weightController = TextEditingController();
  final _timeframeController = TextEditingController(text: '4'); // default 4 weeks
  String? _weightError;
  String? _timeframeError;

  @override
  void dispose() {
    _weightController.dispose();
    _timeframeController.dispose();
    super.dispose();
  }

  /// Longest goal timeframe accepted (two years).
  static const _maxWeeks = 104;

  void _submit() {
    final weight = parseNumberInRange(
      _weightController.text,
      min: InputLimits.weightKgMin,
      max: InputLimits.weightKgMax,
    );
    final timeframe = parseNumberInRange(_timeframeController.text, min: 1, max: _maxWeeks)?.round();

    setState(() {
      _weightError = weight == null
          ? 'Enter ${InputLimits.weightKgMin.round()} to ${InputLimits.weightKgMax.round()} kg'
          : null;
      _timeframeError = timeframe == null ? 'Enter 1 to $_maxWeeks weeks' : null;
    });
    if (weight == null || timeframe == null) return;

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
          Text('What is your target weight?', style: headingStyle),
          const SizedBox(height: AppDimens.space12),
          AppTextField.decimal(
            controller: _weightController,
            hint: 'e.g. 65',
            suffixText: 'kg',
            error: _weightError,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_weightError != null) setState(() => _weightError = null);
            },
          ),
          const SizedBox(height: AppDimens.sectionGap),
          Text(
            'In how many weeks do you want to achieve this?',
            style: headingStyle,
          ),
          const SizedBox(height: AppDimens.space12),
          AppTextField.integer(
            controller: _timeframeController,
            hint: 'e.g. 4',
            suffixText: 'weeks',
            error: _timeframeError,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_timeframeError != null) {
                setState(() => _timeframeError = null);
              }
            },
          ),
        ],
      ),
    );
  }
}
