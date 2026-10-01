import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/set_active_meal_plan.dart';

/// Manual editor for the active diet plan: rename meals, add / remove /
/// rename food items and adjust each meal's calories and macros. Totals are
/// recomputed from the meals. Pops `true` once saved.
class DietPlanEditPage extends StatefulWidget {
  const DietPlanEditPage({super.key});

  @override
  State<DietPlanEditPage> createState() => _DietPlanEditPageState();
}

class _DietPlanEditPageState extends State<DietPlanEditPage> {
  List<_MealDraft>? _meals;
  Map<String, dynamic> _preferences = const {};
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final m in _meals ?? const <_MealDraft>[]) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final getActive = sl<GetActiveMealPlan>();
      final plan = await getActive().withLoadTimeout();
      final prefs = await getActive.preferences().orFallback(const {});
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _meals = [for (final m in plan?.meals ?? const <Meal>[]) _MealDraft(m)];
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _addMeal() => setState(() => _meals!.add(_MealDraft(const Meal(
        name: 'Snack',
        items: [],
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      ))));

  Future<void> _removeMeal(_MealDraft meal) async {
    setState(() => _meals!.remove(meal));
    WidgetsBinding.instance.addPostFrameCallback((_) => meal.dispose());
  }

  MealPlan _buildPlan() {
    final meals = [for (final m in _meals!) m.toMeal()];
    int sum(int Function(Meal) of) => meals.fold(0, (t, m) => t + of(m));
    return MealPlan(
      meals: meals,
      totalCalories: sum((m) => m.calories),
      totalProtein: sum((m) => m.protein),
      totalCarbs: sum((m) => m.carbs),
      totalFat: sum((m) => m.fat),
    );
  }

  Future<void> _save() async {
    final meals = _meals!;
    if (meals.isEmpty) {
      showSmoothSnackBar(
        context,
        message: 'Add at least one meal to the plan.',
        iconColor: AppColors.warning,
      );
      return;
    }
    setState(() {
      for (final m in meals) {
        m.nameError = m.name.text.trim().isEmpty ? 'Name this meal' : null;
      }
    });
    if (meals.any((m) => m.nameError != null)) return;
    setState(() => _saving = true);
    await sl<SetActiveMealPlan>()(_buildPlan(), preferences: _preferences);
    if (!mounted) return;
    showSuccessSnackBar(context, 'Diet plan updated');
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final meals = _meals;
    return AppScaffold(
      header: const AppPageHeader(title: 'Edit Diet Plan'),
      bottomBar: meals == null || meals.isEmpty
          ? null
          : AppPrimaryButton(
              label: 'Save changes',
              isLoading: _saving,
              onTap: _save,
            ),
      body: _failed
          ? Padding(
              padding: const EdgeInsets.only(top: AppDimens.space48),
              child: LoadErrorView(onRetry: _load),
            )
          : meals == null
              ? const Padding(
                  padding: EdgeInsets.only(top: AppDimens.space48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : meals.isEmpty
                  ? const AppInfoNote(
                      message: 'No active plan to edit. Create one first.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TotalsCard(plan: _buildPlan()),
                        const SizedBox(height: AppDimens.cardGap),
                        for (final meal in meals) ...[
                          _MealEditor(
                            key: ObjectKey(meal),
                            draft: meal,
                            onChanged: () => setState(() {}),
                            onRemove: meals.length > 1
                                ? () => _removeMeal(meal)
                                : null,
                          ),
                          const SizedBox(height: AppDimens.cardGap),
                        ],
                        AppSecondaryButton(
                          label: 'Add meal',
                          onTap: _addMeal,
                        ),
                      ],
                    ),
    );
  }
}

/// Editable copy of one meal (controllers for every field).
class _MealDraft {
  final TextEditingController name;
  final List<TextEditingController> items;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  /// Shown on the name field after an attempted save.
  String? nameError;

  _MealDraft(Meal meal)
      : name = TextEditingController(text: meal.name),
        items = [for (final i in meal.items) TextEditingController(text: i)],
        calories = TextEditingController(text: '${meal.calories}'),
        protein = TextEditingController(text: '${meal.protein}'),
        carbs = TextEditingController(text: '${meal.carbs}'),
        fat = TextEditingController(text: '${meal.fat}');

  static int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Meal toMeal() => Meal(
        name: name.text.trim(),
        items: [
          for (final i in items)
            if (i.text.trim().isNotEmpty) i.text.trim(),
        ],
        calories: _int(calories),
        protein: _int(protein),
        carbs: _int(carbs),
        fat: _int(fat),
      );

  void dispose() {
    for (final c in [name, calories, protein, carbs, fat, ...items]) {
      c.dispose();
    }
  }
}

class _TotalsCard extends StatelessWidget {
  final MealPlan plan;

  const _TotalsCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCaption('Daily total'),
          const SizedBox(height: AppDimens.space8),
          Text('${plan.totalCalories} kcal', style: context.text.titleMedium),
          const SizedBox(height: AppDimens.space4),
          Text(
            'Protein ${plan.totalProtein}g · Carbs ${plan.totalCarbs}g · Fat ${plan.totalFat}g',
            style: context.text.bodySmall?.copyWith(color: grey),
          ),
        ],
      ),
    );
  }
}

class _MealEditor extends StatelessWidget {
  final _MealDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _MealEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Meal name',
                  controller: draft.name,
                  hint: 'e.g. Breakfast',
                  error: draft.nameError,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (draft.nameError != null) {
                      draft.nameError = null;
                      onChanged();
                    }
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove meal',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colors.error,
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Text('Items', style: context.text.titleSmall),
          const SizedBox(height: AppDimens.space8),
          for (final item in draft.items) ...[
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: item,
                    hint: 'e.g. 2 Roti',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    draft.items.remove(item);
                    onChanged();
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => item.dispose());
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.items.add(TextEditingController());
                onChanged();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: draft.calories,
                  label: 'kcal',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _NumberField(
                  controller: draft.protein,
                  label: 'Protein g',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: draft.carbs,
                  label: 'Carbs g',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _NumberField(
                  controller: draft.fat,
                  label: 'Fat g',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField.integer(
      label: label,
      controller: controller,
      hint: '0',
      onChanged: (_) => onChanged(),
    );
  }
}
