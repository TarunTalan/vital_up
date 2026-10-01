import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
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
            logsTitle: 'Recent Logs',
            bottomBar: AppPrimaryButton(
              label: '+ Quick Log Water',
              onTap: () => _showQuickLogSheet(context, userId, water, cubit),
            ),
            header: (context, data) {
              final goal = water.getDailyGoal();
              Future<void> setGoal(int value) async {
                await water.setDailyGoal(value.clamp(_minGoalMl, _maxGoalMl));
                cubit.load();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GoalStepperCard(
                    label: 'Daily goal',
                    value: formatMl(goal.toDouble()),
                    onDecrease: goal > _minGoalMl
                        ? () => setGoal(goal - _goalStepMl)
                        : null,
                    onIncrease: goal < _maxGoalMl
                        ? () => setGoal(goal + _goalStepMl)
                        : null,
                  ),
                ],
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

  void _showQuickLogSheet(
    BuildContext context,
    String userId,
    WaterIntakeService water,
    TrendCubit<WaterLogCache> cubit,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            AppDimens.space16,
            context.gutter,
            AppDimens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Log Water Intake', style: context.text.headlineSmall),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space16),
              Row(
                children: [
                  _PresetButton(
                    amountMl: 150,
                    label: '150ml\nCup',
                    icon: Icons.local_cafe_outlined,
                    onTap: () async {
                      await water.addWaterLog(userId, 150);
                      HapticFeedback.mediumImpact();
                      cubit.load();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(width: AppDimens.space8),
                  _PresetButton(
                    amountMl: 250,
                    label: '250ml\nGlass',
                    icon: Icons.local_drink_outlined,
                    onTap: () async {
                      await water.addWaterLog(userId, 250);
                      HapticFeedback.mediumImpact();
                      cubit.load();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(width: AppDimens.space8),
                  _PresetButton(
                    amountMl: 500,
                    label: '500ml\nBottle',
                    icon: Icons.water_drop_outlined,
                    onTap: () async {
                      await water.addWaterLog(userId, 500);
                      HapticFeedback.mediumImpact();
                      cubit.load();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final int amountMl;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PresetButton({
    required this.amountMl,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.water.withAlpha(25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: BorderSide(color: AppColors.water.withAlpha(50)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.space6,
              vertical: AppDimens.space12,
            ),
            child: Column(
              children: [
                Icon(icon, size: AppDimens.iconLg, color: AppColors.water),
                const SizedBox(height: AppDimens.space6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.water,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
