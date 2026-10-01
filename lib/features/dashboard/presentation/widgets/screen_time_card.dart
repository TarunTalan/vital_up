import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import '../cubit/screen_time_cubit.dart';
import '../cubit/screen_time_state.dart';
import '../../domain/entities/app_usage_info.dart';
import 'dashboard_card_header.dart';
import 'trend_widgets.dart';

const _title = 'Screen Time';
const _icon = 'assets/icons/devices.svg';

class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: BlocBuilder<ScreenTimeCubit, ScreenTimeState>(
        builder: (context, state) {
          if (state is ScreenTimeLoading || state is ScreenTimeInitial) {
            return const DashboardCardLoading();
          } else if (state is ScreenTimePermissionDenied) {
            return _buildPermissionState(context);
          } else if (state is ScreenTimeError) {
            return _buildErrorState(context, state.message);
          } else if (state is ScreenTimeLoaded) {
            return _buildLoadedState(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPermissionState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        Text('Permission Required', style: context.text.titleSmall),
        const SizedBox(height: AppDimens.space8),
        Text(
          'To track your screen time, please grant Usage Access permission in settings.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.vColors.grayText),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        AppPrimaryButton(
          label: 'Grant Permission',
          expand: false,
          onTap: () => context.read<ScreenTimeCubit>().openSettings(),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        LoadErrorView(onRetry: context.read<ScreenTimeCubit>().loadStats),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, ScreenTimeLoaded state) {
    final topApps = state.usageStats.take(5).toList();
    final summary = state.weeklySummary;
    final rating = summary?.wellnessRating ?? 'Balanced 📱';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          title: _title,
          iconAsset: _icon,
          trailing: CardLink(
            onTap: () async {
              await context.pushNamed('screen-time-trends');
              if (context.mounted) {
                context.read<ScreenTimeCubit>().loadStats();
              }
            },
          ),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            DashboardMetric(formatDashboardDuration(state.totalDuration)),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space8,
                vertical: AppDimens.space2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Text(
                rating,
                style: context.text.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.cardInnerGap),

        // 7-Day Mini Graph
        if (summary != null && summary.dailyHistory.isNotEmpty) ...[
          _MiniScreenTimeBarChart(history: summary.dailyHistory),
          const SizedBox(height: AppDimens.space12),

          // Statistics Row: Avg, Lowest, Highest
          Row(
            children: [
              Expanded(
                child: _MetricBadge(
                  label: 'Daily Avg',
                  value: formatDashboardDuration(summary.averageDuration),
                  icon: Icons.show_chart_rounded,
                ),
              ),
              const SizedBox(width: AppDimens.space6),
              Expanded(
                child: _MetricBadge(
                  label: 'Lowest',
                  value: summary.lowestDay != null
                      ? formatDashboardDuration(summary.lowestDay!.duration)
                      : '0m',
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppDimens.space6),
              Expanded(
                child: _MetricBadge(
                  label: 'Highest',
                  value: summary.highestDay != null
                      ? formatDashboardDuration(summary.highestDay!.duration)
                      : '0m',
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
        ],

        _TopAppsList(topApps: topApps),
      ],
    );
  }
}

class _MiniScreenTimeBarChart extends StatelessWidget {
  final List<DailyScreenTime> history;

  const _MiniScreenTimeBarChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final maxMinutes = history
        .map((d) => d.duration.inMinutes)
        .fold<int>(60, (max, v) => v > max ? v : max);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space8,
        vertical: AppDimens.space10,
      ),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: v.glassBorder!),
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: history.map((day) {
            final isToday = day.date.day == DateTime.now().day;
            final minutes = day.duration.inMinutes;
            final barHeightFactor = (minutes / maxMinutes).clamp(0.08, 1.0);
            final dayLetter = DateFormat('E').format(day.date).substring(0, 1);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: barHeightFactor,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : AppColors.primary.withAlpha(45),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusXs),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.space4),
                  Text(
                    dayLetter,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? AppColors.primary : v.grayText,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final accent = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space6,
        vertical: AppDimens.space6,
      ),
      decoration: BoxDecoration(
        color: v.primaryFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: v.primaryBorder!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: accent),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 9, color: v.grayText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TopAppsList extends StatefulWidget {
  final List<AppUsageInfo> topApps;

  const _TopAppsList({required this.topApps});

  @override
  State<_TopAppsList> createState() => _TopAppsListState();
}

class _TopAppsListState extends State<_TopAppsList> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;

    if (widget.topApps.isEmpty) {
      return Text(
        'No app usage recorded today.',
        style: context.text.bodyMedium?.copyWith(color: grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Top Apps Today',
                    style: context.text.bodyMedium?.copyWith(color: grey),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: grey,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: AppDimens.space8),
          ...widget.topApps.map((app) => _buildAppRow(context, app)),
        ],
      ],
    );
  }

  Widget _buildAppRow(BuildContext context, AppUsageInfo app) {
    final primary = context.colors.primary;
    final initial = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: primary.withAlpha(25),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 10,
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Expanded(
            child: Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurface),
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Text(
            formatDashboardDuration(app.usageDuration),
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
