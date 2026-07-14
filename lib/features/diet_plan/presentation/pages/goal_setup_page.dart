import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid positive numbers')),
      );
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();
    final cardColor = theme.cardTheme.color ?? Colors.white;

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: const Text('Goal Setup'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('What is your target weight?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 65',
                  suffixText: 'kg',
                  filled: true,
                  fillColor: cardColor.withValues(alpha: 0.72),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('In how many weeks do you want to achieve this?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _timeframeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 4',
                  suffixText: 'weeks',
                  filled: true,
                  fillColor: cardColor.withValues(alpha: 0.72),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary, width: 2),
                  ),
                ),
              ),
              const Spacer(),
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
      ),
    );
  }
}
