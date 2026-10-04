import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/pages/water_trends_page.dart';
import '../cubit/water_intake_cubit.dart';
import '../cubit/water_intake_state.dart';
import 'tracker_log_sheets.dart';

const _metric = TrackerMetric.water;

/// Home card: today's water vs goal with one-tap drinks. Every add shows
/// an Undo snackbar instead of asking to confirm.
class WaterIntakeCard extends StatelessWidget {
  const WaterIntakeCard({super.key});

  Future<void> _open(BuildContext context) async {
    final water = context.read<WaterIntakeCubit>();
    final trend = context.read<TrendCubit<WaterLogCache>>();
    await context.pushNamed(_metric.route);
    water.reload();
    trend.load();
  }

  void _add(BuildContext context, int ml) {
    HapticFeedback.mediumImpact();
    context.read<WaterIntakeCubit>().addWater(ml);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WaterIntakeCubit, WaterIntakeState>(
      // Keep the detail chart's today bar in step with the card.
      listenWhen: (previous, current) =>
          current is WaterIntakeLoaded &&
          (previous is! WaterIntakeLoaded ||
              previous.currentIntakeMl != current.currentIntakeMl ||
              previous.dailyGoalMl != current.dailyGoalMl),
      listener: (context, _) =>
          context.read<TrendCubit<WaterLogCache>>().load(),
      child: BlocConsumer<WaterIntakeCubit, WaterIntakeState>(
        listenWhen: (previous, current) =>
            previous is WaterIntakeLoaded &&
            current is WaterIntakeLoaded &&
            current.todayLogs.length > previous.todayLogs.length,
        listener: (context, state) {
          final added = (state as WaterIntakeLoaded).todayLogs.last.amountMl;
          showSuccessSnackBar(
            context,
            'Added $added ml of water',
            action: SnackBarAction(
              label: 'Undo',
              textColor: context.colors.primary,
              onPressed: context.read<WaterIntakeCubit>().undoLast,
            ),
          );
        },
        builder: (context, state) {
          final cubit = context.read<WaterIntakeCubit>();
          if (state is! WaterIntakeLoaded) {
            return TrackerCardPlaceholder(
              metric: _metric,
              onRetry: state is WaterIntakeError ? cubit.reload : null,
            );
          }
          final current = state.currentIntakeMl;
          final goal = state.dailyGoalMl;
          final left = goal - current;
          return TrackerCard(
            metric: _metric,
            status: TrackerStatus.of(
              value: current.toDouble(),
              goal: goal.toDouble(),
              paceFraction: TrackerStatus.dayPace(),
            ),
            onOpen: () => _open(context),
            actions: [
              TrackerQuickAction(
                label: 'Log water',
                icon: Icons.water_drop_rounded,
                color: _metric.color,
                filled: true,
                semanticLabel: 'Log water',
                onTap: () => showWaterLogSheet(
                  context,
                  onAdd: (ml) => cubit.addWater(ml),
                ),
              ),
            ],
            child: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TrackerProgress(
                    value: WaterTrendsPage.formatMl(current.toDouble()),
                    goal: WaterTrendsPage.formatMl(goal.toDouble()),
                    fraction: goal > 0 ? current / goal : null,
                    color: _metric.color,
                    caption: left > 0
                        ? '${WaterTrendsPage.formatMl(left.toDouble())} to go · '
                              'about ${(left / 250).ceil()} glasses'
                        : 'Goal met — nicely hydrated today.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
