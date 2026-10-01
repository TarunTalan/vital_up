import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

/// Water intake trend: daily totals vs goal, goal stepper and the log list.
class WaterTrendsPage extends StatelessWidget {
  const WaterTrendsPage({super.key});

  static const _goalStepMl = 250;
  static const _minGoalMl = 500;
  static const _maxGoalMl = 6000;

  static String formatMl(double ml) =>
      ml >= 1000 ? '${(ml / 1000).toStringAsFixed(1)} L' : '${ml.round()} ml';

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final userId = auth is AuthAuthenticated ? auth.user.id : 'unknown';
    final water = sl<WaterIntakeService>();

    return BlocProvider(
      create: (_) => TrendCubit<WaterLogCache>(
        (range) => sl<TrendsService>().water(userId, range),
      )..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<WaterLogCache>>();
          return TrendDetailScaffold<WaterLogCache>(
            title: 'Water Intake',
            color: AppColors.water,
            format: formatMl,
            header: (context, data) {
              final goal = water.getDailyGoal();
              Future<void> setGoal(int value) async {
                await water.setDailyGoal(value.clamp(_minGoalMl, _maxGoalMl));
                cubit.load();
              }

              return GoalStepperCard(
                label: 'Daily goal',
                value: formatMl(goal.toDouble()),
                onDecrease: goal > _minGoalMl
                    ? () => setGoal(goal - _goalStepMl)
                    : null,
                onIncrease: goal < _maxGoalMl
                    ? () => setGoal(goal + _goalStepMl)
                    : null,
              );
            },
            logBuilder: (context, log) => Dismissible(
              key: ValueKey(log.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppDimens.space20),
                decoration: BoxDecoration(
                  color: context.vColors.errorFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: context.colors.error),
              ),
              onDismissed: (_) async {
                await water.deleteWaterLog(log.id);
                cubit.load();
              },
              child: TrendLogTile(
                icon: Icons.water_drop_rounded,
                color: AppColors.water,
                title: DateFormat('EEE d MMM').format(log.timestamp),
                subtitle: DateFormat.jm().format(log.timestamp),
                trailing: '${log.amountMl} ml',
              ),
            ),
          );
        },
      ),
    );
  }
}
