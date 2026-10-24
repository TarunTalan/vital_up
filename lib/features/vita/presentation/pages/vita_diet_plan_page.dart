import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/number_formats.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/diet_plan/presentation/widgets/meal_alternatives.dart';
import 'package:vital_up/features/subscription/data/services/ai_quota_service.dart';
import 'package:vital_up/features/subscription/presentation/widgets/ai_quota_line.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_insight_card.dart';

/// The user's active meal plan with Vita's note on why it fits. Edit and
/// New plan sit in the header; asking Vita for a change is the main
/// action.
class VitaDietPlanPage extends StatefulWidget {
  /// True when opened from Vita's chat, so "Ask Vita" returns to that chat
  /// instead of stacking a new one.
  final bool fromChat;

  const VitaDietPlanPage({super.key, this.fromChat = false});

  @override
  State<VitaDietPlanPage> createState() => _VitaDietPlanPageState();
}

class _VitaDietPlanPageState extends State<VitaDietPlanPage> {
  late final Future<VitaDailyInsights?> _insights = sl<VitaRepository>()
      .getDailyInsights();

  void _askVita() {
    if (widget.fromChat) {
      context.pop();
    } else {
      context.pushNamed('vita-chat', extra: 'Can you change my diet plan?');
    }
  }

  Future<void> _edit(DietPlanCubit cubit) async {
    final saved = await context.pushNamed<bool>('diet-plan-edit');
    if (saved == true) cubit.loadActiveMealPlan();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DietPlanCubit>()..loadActiveMealPlan(),
      child: BlocBuilder<DietPlanCubit, DietPlanState>(
        builder: (context, state) {
          final cubit = context.read<DietPlanCubit>();
          final plan = state is DietPlanLoaded ? state.mealPlan : null;
          return AppScaffold(
            header: AppPageHeader(
              title: 'Diet plan',
              action: plan == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppHeaderAction(
                          tooltip: 'Edit plan',
                          svgAsset: 'assets/icons/ui/edit.svg',
                          onTap: () => _edit(cubit),
                        ),
                        const SizedBox(width: AppDimens.space8),
                        AppHeaderAction(
                          tooltip: 'New plan',
                          icon: const Icon(Icons.add_rounded),
                          onTap: () => _createPlan(context),
                        ),
                      ],
                    ),
            ),
            body: switch (state) {
              DietPlanLoading() => const Center(child: VitalUpLoader()),
              DietPlanLoaded(:final mealPlan) => _PlanBody(
                plan: mealPlan,
                insights: _insights,
                onAskVita: _askVita,
              ),
              // No saved plan comes back as DietPlanInitial.
              _ => const _NoPlan(),
            },
          );
        },
      ),
    );
  }
}

class _PlanBody extends StatelessWidget {
  final MealPlan plan;
  final Future<VitaDailyInsights?> insights;
  final VoidCallback onAskVita;

  const _PlanBody({
    required this.plan,
    required this.insights,
    required this.onAskVita,
  });

  @override
  Widget build(BuildContext context) {
    final meals = plan.meals.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerSummaryLine(
          parts: [
            '${formatCount(plan.totalCalories)} kcal',
            '$meals meal${meals == 1 ? '' : 's'}',
            '${plan.totalProtein} g protein',
          ],
        ),
        const SizedBox(height: AppDimens.cardGap),
        FutureBuilder<VitaDailyInsights?>(
          future: insights,
          builder: (context, snapshot) {
            final note = snapshot.data?.dietNote;
            if (note == null || note.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
              child: VitaInsightCard.message(note),
            );
          },
        ),
        for (final (i, meal) in plan.meals.indexed) ...[
          _MealCard(
            meal: meal,
            // The active plan: a swap is saved at once.
            onOptions: () => pickMealAlternative(
              context,
              context.read<DietPlanCubit>(),
              plan,
              i,
              save: true,
            ),
          ),
          const SizedBox(height: AppDimens.cardGap),
        ],
        const SizedBox(height: AppDimens.space4),
        AppPrimaryButton(label: 'Ask Vita to change it', onTap: onAskVita),
      ],
    );
  }
}

/// A meal: name with its kcal on the right, its foods in grey, then the
/// way to its other options when it has some.
class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onOptions;

  const _MealCard({required this.meal, required this.onOptions});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final itemStyle = context.text.bodyMedium?.copyWith(color: grey);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  meal.name,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space12),
              Text(
                '${formatCount(meal.calories)} kcal',
                style: context.text.bodyMedium?.copyWith(color: grey),
              ),
            ],
          ),
          if (meal.items.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            for (var i = 0; i < meal.items.length; i++) ...[
              if (i > 0) const SizedBox(height: AppDimens.space4),
              Text(meal.items[i], style: itemStyle),
            ],
          ],
          if (meal.alternatives.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            MealAlternativesLink(meal: meal, onTap: onOptions),
          ],
        ],
      ),
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VitaInsightCard.message(
          "You don't have a diet plan yet. Tell me what you like and I'll "
          'build one around your goal.',
        ),
        const SizedBox(height: AppDimens.cardGap),
        AppPrimaryButton(
          label: 'Create my diet plan',
          onTap: () => _createPlan(context),
        ),
        const SizedBox(height: AppDimens.space8),
        const AiQuotaLine(quota: AiQuota.dietPlan),
      ],
    );
  }
}

/// Opens the plan setup, then shows whatever plan is active afterwards.
Future<void> _createPlan(BuildContext context) async {
  final cubit = context.read<DietPlanCubit>();
  await context.pushNamed('diet-plan-prefs');
  cubit.loadActiveMealPlan();
}
