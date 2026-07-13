import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';

class DietPlanPreferencesPage extends StatefulWidget {
  const DietPlanPreferencesPage({super.key});

  @override
  State<DietPlanPreferencesPage> createState() => _DietPlanPreferencesPageState();
}

class _DietPlanPreferencesPageState extends State<DietPlanPreferencesPage> {
  String _selectedDiet = 'Any';
  int _mealsPerDay = 4;

  final _dietOptions = ['Any', 'Vegetarian', 'Vegan', 'Eggetarian', 'Pescatarian'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Dietary Preferences'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('What is your dietary preference?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dietOptions.map((diet) {
                  final isSelected = _selectedDiet == diet;
                  return ChoiceChip(
                    label: Text(diet),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedDiet = diet);
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? colors.primary : colors.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
              Text('How many meals per day?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _mealsPerDay > 2 ? () => setState(() => _mealsPerDay--) : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 36),
                    color: colors.primary,
                  ),
                  const SizedBox(width: 32),
                  Text('$_mealsPerDay', style: theme.textTheme.displayMedium),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: _mealsPerDay < 6 ? () => setState(() => _mealsPerDay++) : null,
                    icon: const Icon(Icons.add_circle_outline, size: 36),
                    color: colors.primary,
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: FilledButton(
                  onPressed: () {
                    context.pushNamed(
                      'diet-plan-mode',
                      extra: {
                        'dietaryType': _selectedDiet,
                        'mealsPerDay': _mealsPerDay,
                      },
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: customColors?.buttonText,
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
