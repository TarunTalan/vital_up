import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';

class MealLogHistoryPage extends StatelessWidget {
  const MealLogHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
      child: const _MealLogHistoryView(),
    );
  }
}

class _MealLogHistoryView extends StatelessWidget {
  const _MealLogHistoryView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: AppPageHeader(
        title: "Today's Meals",
        onBack: () => context.pop(),
      ),
      scrollable: false,
      padBody: false,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<MealLogBloc>().add(const LoadTodaysMeals());
          },
          child: BlocConsumer<MealLogBloc, MealLogState>(
            listenWhen: (_, state) => state is MealLogLoaded && state.notice != null,
            listener: (context, state) {
              final notice = (state as MealLogLoaded).notice;
              if (notice != null) showErrorSnackBar(context, notice);
            },
            builder: (context, state) {
              if (state is MealLogLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is MealLogError) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    alignment: Alignment.center,
                    padding: context.pagePadding,
                    child: LoadErrorView(
                      message: state.message,
                      onRetry: () => context.read<MealLogBloc>().add(const LoadTodaysMeals()),
                    ),
                  ),
                );
              }

              if (state is MealLogLoaded) {
                if (state.entries.isEmpty) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIconBadge(
                            size: AppDimens.iconBadgeLarge,
                            icon: const Icon(Icons.restaurant_menu_rounded),
                          ),
                          const SizedBox(height: AppDimens.space16),
                          Text(
                            'No meals logged today.',
                            style: context.text.bodyLarge?.copyWith(
                              color: context.vColors.grayText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.gutter,
                    vertical: AppDimens.sectionGap,
                  ),
                  itemCount: state.entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.cardGap),
                  itemBuilder: (context, index) {
                    final entry = state.entries[index];
                    return _MealLogTile(entry: entry);
                  },
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _MealLogTile extends StatelessWidget {
  final MealLogEntry entry;

  const _MealLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeFormat = DateFormat('h:mm a');

    return AppCard(
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MealTypeBadge(mealType: entry.mealType),
              const Spacer(),
              Text(
                timeFormat.format(entry.capturedAt),
                style: context.text.bodySmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
              const SizedBox(width: AppDimens.space4),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  context.read<MealLogBloc>().add(DeleteMealLogEntry(entry.id));
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: AppDimens.iconMd,
                  color: colors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            entry.items.map((i) => i.name).join(', '),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: AppDimens.space12),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              _MacroPill(
                label: 'Cals',
                value: '${entry.totalCalories.toInt()}',
                color: colors.primary,
              ),
              if (entry.nutrition.isNotEmpty) ...[
                _MacroPill(
                  label: 'P',
                  value: '${entry.nutrition.first.proteinG.toInt()}g',
                  color: AppColors.scanProtein,
                ),
                _MacroPill(
                  label: 'C',
                  value: '${entry.nutrition.first.carbsG.toInt()}g',
                  color: AppColors.scanCarbs,
                ),
                _MacroPill(
                  label: 'F',
                  value: '${entry.nutrition.first.fatG.toInt()}g',
                  color: AppColors.scanFat,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MealTypeBadge extends StatelessWidget {
  final MealType mealType;

  const _MealTypeBadge({required this.mealType});

  String get _label {
    switch (mealType) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
      case MealType.snack:     return 'Snack';
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: v.primaryFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: v.primaryBorder!),
      ),
      child: Text(
        _label,
        style: context.text.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space8,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.27)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: context.text.bodySmall?.copyWith(
                color: context.vColors.grayText,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
