import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
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

  /// "250 ml", "1.25 L", "2.5 L". Litres show a second decimal only
  /// when there is one, never rounded up, so 2,960 ml reads "2.96 L", not
  /// "3.0 L of 3.0 L" before the goal is reached, and 1,250 ml isn't
  /// undersold as "1.2 L".
  static String formatMl(double ml) {
    if (!ml.isFinite || ml < 1000) {
      return '${(ml.isFinite ? ml : 0).floor()} ml';
    }
    final litres = ((ml / 10).floor() / 100).toStringAsFixed(2);
    return '${litres.endsWith('0') ? litres.substring(0, litres.length - 1) : litres} L';
  }

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
                onAdd: (ml) async {
                  await water.addWaterLog(userId, ml);
                  return true;
                },
              );
              if (added != null) cubit.load();
            },
            dateOf: (log) => log.timestamp,
            allLogs: () async => (await water.getLogsBetween(
              userId,
              DateTime(2000),
              nextDay(startOfDay(DateTime.now())),
            )).reversed.toList(),
            daySummary: (logs) =>
                formatMl(logs.fold<double>(0, (s, l) => s + l.amountMl)),
            logBuilder: (context, log) => LogHistoryCard(
              icon: Icon(_presetFor(log.amountMl)?.icon ?? metric.icon),
              color: metric.color,
              title: _presetFor(log.amountMl)?.label ?? 'Water',
              subtitle: DateFormat.jm().format(log.timestamp),
              value: formatMl(log.amountMl.toDouble()),
              deleteNoun: 'drink',
              onDelete: () => deleteTrackerLog(
                context,
                context.read<TrendCubit<WaterLogCache>>(),
                log,
                () => water.deleteWaterLog(log.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
