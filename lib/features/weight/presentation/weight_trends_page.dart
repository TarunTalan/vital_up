import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_insights.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import 'package:vital_up/features/weight/presentation/weight_entry_sheet.dart';

const _metric = TrackerMetric.weight;

/// Within this many kg of the goal counts as reached.
const _goalReachedKg = 0.5;

String _signed(WeightUnit unit, double kg) {
  // Round first: 0.04 kg must read "0.0 kg", not "+0.0 kg".
  final v = double.parse(unit.fromKg(kg).toStringAsFixed(1));
  final sign = v > 0
      ? '+'
      : v < 0
      ? '−'
      : '';
  return '$sign${v.abs().toStringAsFixed(1)} ${unit.label}';
}

/// Status of the latest weight against the goal weight.
TrackerStatus _status(double? latestKg, double? goalKg) {
  if (latestKg == null) return TrackerStatus.notLogged;
  if (goalKg == null) return TrackerStatus.noGoal;
  return (latestKg - goalKg).abs() <= _goalReachedKg
      ? TrackerStatus.done
      : TrackerStatus.onTrack;
}

String? _toGoal(WeightUnit unit, double? latestKg, double? goalKg) {
  if (latestKg == null || goalKg == null) return null;
  final diff = goalKg - latestKg;
  if (diff.abs() <= _goalReachedKg) return 'Goal reached';
  return '${unit.format(diff.abs())} to ${diff < 0 ? 'lose' : 'gain'}';
}

/// Weight: latest vs goal weight, daily trend, change and every entry.
class WeightTrendsPage extends StatelessWidget {
  const WeightTrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = sl<WeightService>();
    return FutureBuilder<WeightUnit>(
      future: service.unit(),
      builder: (context, snap) {
        final unit = snap.data ?? WeightUnit.kg;
        return BlocProvider(
          create: (_) =>
              TrendCubit<WeightLogCache>(service.trend, range: TrendRange.month)
                ..load(),
          child: Builder(
            builder: (context) {
              final cubit = context.read<TrendCubit<WeightLogCache>>();
              return TrackerDetailScaffold<WeightLogCache>(
                metric: _metric,
                noun: 'your weight',
                // Day-to-day weight is mostly noise and most days have no
                // weigh-in, so weight shows weeks and months only.
                ranges: const [TrendRange.month, TrendRange.halfYear],
                format: (kg) => unit.format(kg),
                axisFormat: (kg) => unit.fromKg(kg).toStringAsFixed(0),
                heroLabel: 'Latest',
                today: (data) {
                  final latest = data.logs.firstOrNull;
                  final goal = data.series.goal;
                  return TrackerToday(
                    value: latest == null ? '-' : unit.format(latest.weightKg),
                    caption: latest == null
                        ? 'Log your weight to start your trend'
                        : 'Logged ${DateFormat('EEE d MMM, h:mm a').format(latest.timestamp)}',
                    status: _status(latest?.weightKg, goal),
                    statusLabel: _toGoal(unit, latest?.weightKg, goal),
                    logged:
                        latest != null &&
                        isSameDay(latest.timestamp, DateTime.now()),
                    fraction: _progress(data.logs, goal),
                  );
                },
                goalLabel: (data) => data.series.goal == null
                    ? null
                    : 'Goal weight · ${unit.format(data.series.goal!)}',
                onEditGoal: () async {
                  if (await editWeightGoal(context)) cubit.load();
                },
                insights: (data) => _changeInsights(data.logs, unit),
                emptyLogs: 'No weight logged today.',
                dateOf: (log) => log.timestamp,
                allLogs: () => service.between(
                  DateTime(2000),
                  nextDay(startOfDay(DateTime.now())),
                ),
                editLabel: 'Update weight',
                onLog: () async {
                  if (await showWeightEntrySheet(context)) cubit.load();
                },
                logBuilder: (context, log) => TrackerLogTile(
                  id: log.id,
                  icon: log.source == 'health'
                      ? Icons.watch_rounded
                      : _metric.icon,
                  color: _metric.color,
                  title: unit.format(log.weightKg),
                  subtitle:
                      '${DateFormat('EEE d MMM · h:mm a').format(log.timestamp)}'
                      ' · ${log.source == 'health' ? 'Synced' : 'Manual'}',
                  onDelete: () => deleteTrackerLog(
                    context,
                    context.read<TrendCubit<WeightLogCache>>(),
                    log,
                    () => service.delete(log),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Share of the way from the oldest entry in range to the goal.
  static double? _progress(List<WeightLogCache> logs, double? goal) {
    if (goal == null || logs.length < 2) return null;
    final start = logs.last.weightKg;
    final latest = logs.first.weightKg;
    final total = (start - goal).abs();
    if (total < _goalReachedKg) return 1;
    return (1 - (latest - goal).abs() / total).clamp(0.0, 1.0);
  }

  static List<TrackerInsight> _changeInsights(
    List<WeightLogCache> logs,
    WeightUnit unit,
  ) {
    if (logs.length < 2) return const [];
    final change = logs.first.weightKg - logs.last.weightKg;
    final days = logs.first.timestamp.difference(logs.last.timestamp).inDays;
    if (days < 1) return const [];
    final perWeek = change / days * 7;
    return [
      TrackerInsight(
        change <= 0 ? Icons.south_east_rounded : Icons.north_east_rounded,
        '${_signed(unit, change)} over $days days '
        '(${_signed(unit, perWeek)} a week).',
      ),
    ];
  }
}

/// Home card: latest weight, distance to goal, quick log. Reads a
/// [TrendCubit<WeightLogCache>] provided by the dashboard.
class WeightCard extends StatelessWidget {
  const WeightCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeightUnit>(
      future: sl<WeightService>().unit(),
      builder: (context, snap) {
        final unit = snap.data ?? WeightUnit.kg;
        return BlocBuilder<
          TrendCubit<WeightLogCache>,
          TrendState<WeightLogCache>
        >(
          builder: (context, state) {
            final cubit = context.read<TrendCubit<WeightLogCache>>();
            final data = state.data;
            if (data == null) {
              return TrackerCardPlaceholder(
                metric: _metric,
                onRetry: state.error != null ? cubit.load : null,
              );
            }
            final latest = data.logs.firstOrNull;
            final goal = data.series.goal;
            final status = _status(latest?.weightKg, goal);
            // Like the other cards: once today's weight is in, say so and
            // offer to update it instead of a fresh log.
            final loggedToday =
                latest != null &&
                DateUtils.isSameDay(latest.timestamp, DateTime.now());
            return TrackerCard(
              metric: _metric,
              status: loggedToday ? TrackerStatus.done : status,
              statusLabel: loggedToday && status != TrackerStatus.done
                  ? 'Logged today'
                  : null,
              onOpen: () async {
                await context.pushNamed(_metric.route);
                cubit.load();
              },
              actions: [
                TrackerQuickAction(
                  label: loggedToday ? 'Update' : _metric.logLabel,
                  icon: loggedToday ? Icons.edit_rounded : _metric.logIcon,
                  color: _metric.color,
                  filled: true,
                  onTap: () async {
                    if (await showWeightEntrySheet(context)) cubit.load();
                  },
                ),
              ],
              child: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    latest == null
                        ? TrackerPrompt(
                            title: 'No weight logged',
                            color: _metric.color,
                          )
                        : TrackerProgress(
                            value: unit.format(latest.weightKg),
                            goal: goal == null ? null : unit.format(goal),
                            color: _metric.color,
                            fraction: WeightTrendsPage._progress(
                              data.logs,
                              goal,
                            ),
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
