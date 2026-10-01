import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_insight_card.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_page_body.dart';

/// Figma `health coach/ diet plan` (1912:17481) — shows the user's active
/// meal plan with Vita's rationale.
class VitaDietPlanPage extends StatefulWidget {
  /// True when opened from Vita Chat, so "Ask Vita" returns to that chat
  /// instead of stacking a new one.
  final bool fromChat;

  const VitaDietPlanPage({super.key, this.fromChat = false});

  @override
  State<VitaDietPlanPage> createState() => _VitaDietPlanPageState();
}

class _VitaDietPlanPageState extends State<VitaDietPlanPage> {
  late final Future<VitaDailyInsights?> _insights =
      sl<VitaRepository>().getDailyInsights();

  void _askVita() {
    if (widget.fromChat) {
      context.pop();
    } else {
      context.pushNamed('vita-chat', extra: 'Can you tweak my diet plan?');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DietPlanCubit>()..loadActiveMealPlan(),
      child: AppScaffold(
        header: const AppTitleBar(title: 'Diet Plan'),
        bodyPadding: vitaBodyPadding(context),
        body: BlocBuilder<DietPlanCubit, DietPlanState>(
          builder: (context, state) {
            if (state is DietPlanLoading) {
              return const Padding(
                padding: EdgeInsets.only(top: AppDimens.space48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state is! DietPlanLoaded) return const _NoPlan();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<VitaDailyInsights?>(
                  future: _insights,
                  builder: (context, snapshot) {
                    final note = snapshot.data?.dietNote;
                    if (note == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.space16),
                      child: VitaInsightCard(child: _VitaSays(note)),
                    );
                  },
                ),
                for (final meal in state.mealPlan.meals) ...[
                  _MealCard(meal: meal),
                  const SizedBox(height: AppDimens.space16),
                ],
                AppPrimaryButton(
                  label: 'Ask Vita to tweak this plan',
                  leadingIcon: SvgPicture.asset(
                    VitaIcons.caretLeft,
                    width: AppDimens.iconXs,
                    height: AppDimens.iconXs,
                  ),
                  onTap: _askVita,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VitaSays extends StatelessWidget {
  final String note;

  const _VitaSays(this.note);

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Vita says: ',
            style: context.text.titleSmall?.copyWith(color: onSurface),
          ),
          TextSpan(text: note),
        ],
      ),
      style: context.text.bodyMedium?.copyWith(color: onSurface),
    );
  }
}

/// Figma `card/list`: meal name + calorie pill, then indented grey items.
class _MealCard extends StatelessWidget {
  final Meal meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final itemStyle = context.text.bodyMedium?.copyWith(
      color: context.vColors.grayText,
    );

    return AppCard(
      blur: true,
      sheen: false,
      shadow: AppShadows.soft,
      padding: VitaDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meal.name,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: VitaDimens.pillPadding,
                decoration: BoxDecoration(
                  color: VitaColors.pillFill,
                  borderRadius: BorderRadius.circular(VitaDimens.pillRadius),
                ),
                child: Text(
                  '${meal.calories} cal',
                  style: context.text.bodySmall?.copyWith(
                    color: VitaColors.pillText,
                  ),
                ),
              ),
            ],
          ),
          if (meal.items.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space12),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VitaDimens.mealItemIndent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < meal.items.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppDimens.space6),
                    Text(meal.items[i], style: itemStyle),
                  ],
                ],
              ),
            ),
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
          "You don't have a diet plan yet. Tell me your preferences and "
          "I'll build one around your health data.",
        ),
        const SizedBox(height: AppDimens.space16),
        AppPrimaryButton(
          label: 'Create my diet plan',
          showRightArrow: true,
          onTap: () => context.pushNamed('diet-plan-prefs'),
        ),
      ],
    );
  }
}
