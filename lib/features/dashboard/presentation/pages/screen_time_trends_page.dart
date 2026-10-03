import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/dashboard/domain/entities/app_usage_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_state.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';

class ScreenTimeTrendsPage extends StatelessWidget {
  const ScreenTimeTrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      onRefresh: () async => context.read<ScreenTimeCubit>().loadStats(),
      header: const AppPageHeader(title: 'Screen Time Trends'),
      body: BlocBuilder<ScreenTimeCubit, ScreenTimeState>(
        builder: (context, state) {
          if (state is ScreenTimeLoading || state is ScreenTimeInitial) {
            return const Center(child: VitalUpLoader());
          } else if (state is ScreenTimeError) {
            return LoadErrorView(
              onRetry: context.read<ScreenTimeCubit>().loadStats,
            );
          } else if (state is ScreenTimeLoaded) {
            final summary = state.weeklySummary;
            final topApps = state.usageStats;

            return ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                AppDimens.sectionGap + context.safePadding.bottom,
              ),
              children: [
                // 1. Primary Today & Wellness Banner
                _buildTodayHeader(context, state.totalDuration, summary),
                const SizedBox(height: AppDimens.sectionGap),

                // 2. 7-Day Bar Chart Graph
                if (summary != null && summary.dailyHistory.isNotEmpty) ...[
                  _buildWeeklyChartCard(context, summary),
                  const SizedBox(height: AppDimens.sectionGap),

                  // 3. Statistics Grid (Lowest, Highest, Average, Comparison)
                  _buildStatsGrid(context, summary),
                  const SizedBox(height: AppDimens.sectionGap),
                ],

                // 4. App Usage Breakdown
                _buildAppUsageSection(context, topApps),
                const SizedBox(height: AppDimens.sectionGap),

                // 5. Vita Digital Wellness Tips
                _buildDigitalDetoxTips(context),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTodayHeader(
    BuildContext context,
    Duration totalToday,
    ScreenTimeWeeklySummary? summary,
  ) {
    final v = context.vColors;
    final rating = summary?.wellnessRating ?? 'Balanced 📱';

    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Screen Time',
                style: context.text.titleSmall?.copyWith(color: v.grayText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space10,
                  vertical: AppDimens.space4,
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
          const SizedBox(height: AppDimens.space8),
          Text(
            formatDashboardDuration(totalToday),
            style: context.text.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          if (summary != null && summary.changeVsYesterdayPct != 0.0) ...[
            const SizedBox(height: AppDimens.space4),
            Row(
              children: [
                Icon(
                  summary.changeVsYesterdayPct < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: AppDimens.iconXs,
                  color: summary.changeVsYesterdayPct < 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: AppDimens.space4),
                Text(
                  '${summary.changeVsYesterdayPct.abs().toStringAsFixed(1)}% '
                  '${summary.changeVsYesterdayPct < 0 ? 'less' : 'more'} than yesterday',
                  style: context.text.bodySmall?.copyWith(
                    color: summary.changeVsYesterdayPct < 0
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyChartCard(
    BuildContext context,
    ScreenTimeWeeklySummary summary,
  ) {
    final v = context.vColors;
    final maxMinutes = summary.dailyHistory
        .map((d) => d.duration.inMinutes)
        .fold<int>(60, (max, v) => v > max ? v : max);

    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Activity Graph',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Avg: ${formatDashboardDuration(summary.averageDuration)}/d',
                style: context.text.labelSmall?.copyWith(
                  color: v.grayText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space20),
          // Bar chart
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: summary.dailyHistory.map((day) {
                final isToday = day.date.day == DateTime.now().day;
                final minutes = day.duration.inMinutes;
                final barHeightFactor = (minutes / maxMinutes).clamp(0.06, 1.0);
                final dayName = DateFormat('E').format(day.date).substring(0, 1);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        minutes > 0 ? '${minutes ~/ 60}h' : '',
                        style: TextStyle(
                          fontSize: 9,
                          color: isToday ? AppColors.primary : v.grayText,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: AppDimens.space4),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: barHeightFactor,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.primary.withAlpha(50),
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                              border: isToday
                                  ? Border.all(color: Colors.white, width: 1.5)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.space8),
                      Text(
                        dayName,
                        style: context.text.labelSmall?.copyWith(
                          fontSize: 11,
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
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    ScreenTimeWeeklySummary summary,
  ) {
    final lowest = summary.lowestDay;
    final highest = summary.highestDay;

    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            title: 'Daily Average',
            value: formatDashboardDuration(summary.averageDuration),
            subtitle: 'Past 7 days',
            icon: Icons.pie_chart_outline_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: _StatMiniCard(
            title: 'Lowest Day',
            value: lowest != null ? formatDashboardDuration(lowest.duration) : '0m',
            subtitle: lowest != null ? DateFormat('EEEE').format(lowest.date) : 'N/A',
            icon: Icons.arrow_downward_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Expanded(
          child: _StatMiniCard(
            title: 'Highest Day',
            value: highest != null ? formatDashboardDuration(highest.duration) : '0m',
            subtitle: highest != null ? DateFormat('EEEE').format(highest.date) : 'N/A',
            icon: Icons.arrow_upward_rounded,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildAppUsageSection(
    BuildContext context,
    List<AppUsageInfo> apps,
  ) {
    final v = context.vColors;

    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Breakdown Today',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          if (apps.isEmpty)
            Text(
              'No app usage recorded today.',
              style: context.text.bodyMedium?.copyWith(color: v.grayText),
            )
          else ...[
            ...apps.take(8).map((app) {
              final initial = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.space6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.space10),
                    Expanded(
                      child: Text(
                        app.appName,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      formatDashboardDuration(app.usageDuration),
                      style: context.text.bodyMedium?.copyWith(
                        color: v.grayText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDigitalDetoxTips(BuildContext context) {
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space16),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimens.space8),
            decoration: BoxDecoration(
              color: AppColors.teal.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.self_improvement_rounded,
              color: AppColors.teal,
              size: AppDimens.iconMd,
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vita Wellness Recommendation',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimens.space4),
                Text(
                  'Take a 5-minute eye break for every 45 minutes of continuous phone usage to reduce cognitive fatigue and improve sleep onset.',
                  style: context.text.bodySmall?.copyWith(
                    color: v.grayText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space10),
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
              Icon(icon, size: AppDimens.iconXs, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 10,
                    color: v.grayText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            value,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              fontSize: 9,
              color: v.grayText,
            ),
          ),
        ],
      ),
    );
  }
}
