import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';

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
    final colors = context.colors;
    final v = context.vColors;

    return AppScaffold(
      header: const AppPageHeader(title: 'Dietary Preferences'),
      bottomBar: AppPrimaryButton(
        label: 'Continue',
        onTap: () {
          context.pushNamed(
            'diet-plan-mode',
            extra: {
              'dietaryType': _selectedDiet,
              'mealsPerDay': _mealsPerDay,
            },
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is your dietary preference?', style: context.text.headlineSmall),
          const SizedBox(height: AppDimens.space16),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: _dietOptions.map((diet) {
              final isSelected = _selectedDiet == diet;
              return ChoiceChip(
                label: Text(diet),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedDiet = diet);
                },
                backgroundColor: v.glassFill,
                selectedColor: v.primaryTint,
                side: BorderSide(
                  color: isSelected ? colors.primary : v.glassBorder!,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                ),
                labelStyle: context.text.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimens.space32),
          Text('How many meals per day?', style: context.text.headlineSmall),
          const SizedBox(height: AppDimens.space16),
          AppCard(
            padding: AppDimens.cardPaddingCompact,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _mealsPerDay > 2 ? () => setState(() => _mealsPerDay--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: AppDimens.iconXl,
                  color: colors.primary,
                ),
                const SizedBox(width: AppDimens.space32),
                Text(
                  '$_mealsPerDay',
                  style: AppTextStyles.metricLarge.copyWith(color: colors.onSurface),
                ),
                const SizedBox(width: AppDimens.space32),
                IconButton(
                  onPressed: _mealsPerDay < 6 ? () => setState(() => _mealsPerDay++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: AppDimens.iconXl,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
