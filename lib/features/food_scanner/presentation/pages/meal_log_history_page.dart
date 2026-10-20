import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';

class MealLogHistoryPage extends StatelessWidget {
  const MealLogHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MealLogBloc>()..add(const LoadAllMealLogs()),
      child: const _MealLogHistoryView(),
    );
  }
}

class _MealLogHistoryView extends StatelessWidget {
  const _MealLogHistoryView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: AppPageHeader(title: 'Meal history', onBack: () => context.pop()),
      scrollable: false,
      padBody: false,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            final done = Completer<void>();
            context.read<MealLogBloc>().add(LoadAllMealLogs(done: done));
            // The spinner stays until the list has reloaded.
            await done.future.timeout(kLoadTimeout, onTimeout: () {});
          },
          child: BlocConsumer<MealLogBloc, MealLogState>(
            listenWhen: (_, state) =>
                state is MealLogLoaded && state.notice != null,
            listener: (context, state) {
              final notice = (state as MealLogLoaded).notice;
              if (notice != null) showErrorSnackBar(context, notice);
            },
            builder: (context, state) {
              if (state is MealLogLoading) {
                return const Center(child: VitalUpLoader());
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
                      onRetry: () => context.read<MealLogBloc>().add(
                        const LoadAllMealLogs(),
                      ),
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
                      child: const TrackerEmptyState(
                        metric: TrackerMetric.nutrition,
                        message: 'What you log will show up here.',
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

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<MealLogBloc>();
    final delete = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: const Text('It will be removed from your log and totals.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true || bloc.isClosed) return;
    bloc.add(DeleteMealLogEntry(entry.id));
  }

  String get _mealLabel => switch (entry.mealType) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snack',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LogHistoryCard(
      badge: LogTypeBadge(label: _mealLabel),
      at: entry.capturedAt,
      title: entry.items.map((i) => i.name).join(', '),
      onDelete: () => _confirmDelete(context),
      figures: [
        LogValuePill(
          label: 'Cals',
          value: '${entry.totalCalories.round()}',
          color: colors.primary,
        ),
        if (entry.nutrition.isNotEmpty) ...[
          LogValuePill(
            label: 'P',
            value: '${_sum(entry, (n) => n.proteinG)}g',
            color: AppColors.scanProtein,
          ),
          LogValuePill(
            label: 'C',
            value: '${_sum(entry, (n) => n.carbsG)}g',
            color: AppColors.scanCarbs,
          ),
          LogValuePill(
            label: 'F',
            value: '${_sum(entry, (n) => n.fatG)}g',
            color: AppColors.scanFat,
          ),
        ],
      ],
    );
  }
}

/// A macro over every item of the meal (the calories shown are the total).
int _sum(MealLogEntry entry, double Function(NutritionInfo n) of) =>
    entry.nutrition.fold<double>(0, (sum, n) => sum + of(n)).round();
