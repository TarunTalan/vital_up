import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';

/// Water: today vs goal, daily trend, insights and every drink logged.
class WaterTrendsPage extends StatelessWidget {
  const WaterTrendsPage({super.key});

  static String formatMl(double ml) =>
      ml >= 1000 ? '${(ml / 1000).toStringAsFixed(1)} L' : '${ml.round()} ml';

  static ({int ml, String label, IconData icon})? _presetFor(int ml) {
    for (final p in waterPresets) {
      if (p.ml == ml) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final userId = auth is AuthAuthenticated ? auth.user.id : 'unknown';
    final water = sl<WaterIntakeService>();
    const metric = TrackerMetric.water;

    return BlocProvider(
      create: (_) => TrendCubit<WaterLogCache>(
        (range) => sl<TrendsService>().water(userId, range),
      )..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<WaterLogCache>>();
          return TrackerDetailScaffold<WaterLogCache>(
            metric: metric,
            noun: 'water',
            format: formatMl,
            goalLabel: (data) => data.series.goal == null
                ? null
                : 'Daily goal · ${formatMl(data.series.goal!)}',
            onEditGoal: () async {
              if (await editWaterGoal(context)) cubit.load();
            },
            insights: (data) {
              final today = data.series.today ?? 0;
              final goal = data.series.goal ?? 0;
              final left = goal - today;
              return [
                if (left > 0)
                  TrackerInsight(
                    Icons.local_drink_rounded,
                    '${formatMl(left)} to go today — about '
                    '${(left / 250).ceil()} glasses.',
                  ),
              ];
            },
            onLog: () async {
              final added = await showWaterLogSheet(
                context,
                onAdd: (ml) => water.addWaterLog(userId, ml),
              );
              if (added != null) cubit.load();
            },
            logBuilder: (context, log) => TrackerLogTile(
              id: log.id,
              icon: _presetFor(log.amountMl)?.icon ?? metric.icon,
              color: metric.color,
              title: _presetFor(log.amountMl)?.label ?? 'Water',
              subtitle: DateFormat('EEE d MMM · h:mm a').format(log.timestamp),
              trailing: '${log.amountMl} ml',
              onDelete: () async {
                await water.deleteWaterLog(log.id);
                cubit.load();
              },
            ),
          );
        },
      ),
    );
  }
}
