import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import 'package:vital_up/features/weight/presentation/weight_entry_sheet.dart';

/// Accent for weight charts and badges.
const weightColor = AppColors.teal;

/// Weight trend: last weight per day vs goal weight, change over the
/// period, and the entries (swipe to delete).
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
          create: (_) => TrendCubit<WeightLogCache>(service.trend)..load(),
          child: Builder(
            builder: (context) {
              final cubit = context.read<TrendCubit<WeightLogCache>>();
              return TrendDetailScaffold<WeightLogCache>(
                title: 'Weight',
                color: weightColor,
                format: (kg) => unit.format(kg),
                axisFormat: (kg) => unit.fromKg(kg).toStringAsFixed(0),
                logsTitle: 'Entries',
                emptyLogs: 'No weight logged in this period yet.',
                bottomBar: AppPrimaryButton(
                  label: 'Log weight',
                  onTap: () async {
                    if (await showWeightEntrySheet(context)) cubit.load();
                  },
                ),
                header: (context, data) => _ChangeCard(
                  logs: data.logs,
                  goal: data.series.goal,
                  unit: unit,
                ),
                logBuilder: (context, log) => Dismissible(
                  key: ValueKey(log.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppDimens.space16),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: context.colors.error,
                    ),
                  ),
                  onDismissed: (_) async {
                    await service.delete(log);
                    cubit.load();
                  },
                  child: TrendLogTile(
                    icon: log.source == 'health'
                        ? Icons.watch_rounded
                        : Icons.monitor_weight_rounded,
                    color: weightColor,
                    title: DateFormat('EEE d MMM').format(log.timestamp),
                    subtitle:
                        '${DateFormat.jm().format(log.timestamp)}'
                        ' · ${log.source == 'health' ? 'Synced' : 'Manual'}',
                    trailing: unit.format(log.weightKg),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Change over the selected period and distance to the goal weight.
class _ChangeCard extends StatelessWidget {
  final List<WeightLogCache> logs;
  final double? goal;
  final WeightUnit unit;

  const _ChangeCard({
    required this.logs,
    required this.goal,
    required this.unit,
  });

  String _signed(double kg) {
    final v = unit.fromKg(kg);
    return '${v > 0
            ? '+'
            : v < 0
            ? '−'
            : ''}'
        '${v.abs().toStringAsFixed(1)} ${unit.label}';
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();
    final latest = logs.first.weightKg;
    final change = latest - logs.last.weightKg;
    final toGoal = goal == null ? null : goal! - latest;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Row(
        children: [
          Expanded(
            child: _Figure(
              label: 'Change',
              value: logs.length < 2 ? '—' : _signed(change),
            ),
          ),
          Expanded(
            child: _Figure(
              label: 'Goal',
              value: goal == null ? 'Not set' : unit.format(goal!),
            ),
          ),
          Expanded(
            child: _Figure(
              label: 'To go',
              value: toGoal == null
                  ? '—'
                  : toGoal.abs() < 0.25
                  ? 'Reached'
                  : _signed(toGoal),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;

  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
        const SizedBox(height: AppDimens.space4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: context.text.titleMedium),
        ),
      ],
    );
  }
}

/// Dashboard card: latest weight, 7-day mini chart, log button.
class WeightCard extends StatelessWidget {
  final VoidCallback onOpenTrends;

  const WeightCard({super.key, required this.onOpenTrends});

  @override
  Widget build(BuildContext context) {
    final service = sl<WeightService>();
    return BlocProvider(
      create: (_) => TrendCubit<WeightLogCache>(service.trend)..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<WeightLogCache>>();
          return AppCard(
            width: double.infinity,
            child: FutureBuilder<WeightUnit>(
              future: service.unit(),
              builder: (context, snap) {
                final unit = snap.data ?? WeightUnit.kg;
                return BlocBuilder<
                  TrendCubit<WeightLogCache>,
                  TrendState<WeightLogCache>
                >(
                  builder: (context, state) {
                    final logs = state.data?.logs ?? const <WeightLogCache>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppIconBadge(
                              color: weightColor,
                              icon: Icon(Icons.monitor_weight_rounded),
                            ),
                            const SizedBox(width: AppDimens.space12),
                            Expanded(
                              child: Text(
                                'Weight',
                                style: context.text.titleSmall,
                              ),
                            ),
                            CardLink(onTap: onOpenTrends),
                          ],
                        ),
                        const SizedBox(height: AppDimens.cardInnerGap),
                        Text(
                          logs.isEmpty ? '—' : unit.format(logs.first.weightKg),
                          style: AppTextStyles.metric.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                        Text(
                          logs.isEmpty
                              ? 'Log your weight to see your trend.'
                              : 'Last logged ${DateFormat('d MMM').format(logs.first.timestamp)}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.vColors.grayText,
                          ),
                        ),
                        const SizedBox(height: AppDimens.cardInnerGap),
                        MiniTrend<WeightLogCache>(
                          color: weightColor,
                          valueFormatter: (kg) => unit.format(kg),
                        ),
                        const SizedBox(height: AppDimens.cardInnerGap),
                        AppSecondaryButton(
                          label: 'Log weight',
                          onTap: () async {
                            if (await showWeightEntrySheet(context)) {
                              cubit.load(TrendRange.week);
                            }
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
