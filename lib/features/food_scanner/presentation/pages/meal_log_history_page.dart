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
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/meal_log_card.dart';

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

                // Each day's heading with its calories, then its meals,
                // as in every tracker's history.
                final items = <Widget>[];
                for (final (day, meals) in groupLogsByDay(
                  state.entries,
                  (MealLogEntry m) => m.capturedAt,
                )) {
                  items.add(
                    Padding(
                      padding: EdgeInsets.only(
                        top: items.isEmpty ? 0 : AppDimens.space12,
                      ),
                      child: LogDayHeader(
                        formatLogDay(day),
                        summary: formatMealKcal(
                          meals.fold<double>(0, (s, m) => s + m.totalCalories),
                        ),
                      ),
                    ),
                  );
                  for (final meal in meals) {
                    items.add(_MealLogTile(entry: meal));
                  }
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.gutter,
                    vertical: AppDimens.sectionGap,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.cardGap),
                  itemBuilder: (context, index) => items[index],
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
    final bloc = context.read<MealLogBloc>();
    return MealLogCard(
      entry: entry,
      onDelete: () {
        if (!bloc.isClosed) bloc.add(DeleteMealLogEntry(entry.id));
      },
    );
  }
}
