import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/circular_sleep_clock.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

/// Sleep trends & detail page matching the Figma design:
/// - Topbar with back & circular calendar action
/// - TODAY duration card with edit action and start/end time display
/// - 7-DAY TREND column chart with top-rounded bars, tap/hold to view start/end times
/// - INSIGHTS gradient card with dynamic sleep debt, consistency & quality analytics
/// - Goal stepper & recovery stats
/// - Nights & Quality logs list
/// - Bottom bar: interactive sleep clock logger
class SleepTrendsPage extends StatefulWidget {
  const SleepTrendsPage({super.key});

  static const _goalStepMin = 30;
  static const _minGoalMin = 240;
  static const _maxGoalMin = 720;

  static String formatHours(double hours) =>
      formatDashboardDuration(Duration(minutes: (hours * 60).round()));

  @override
  State<SleepTrendsPage> createState() => _SleepTrendsPageState();
}

class _SleepTrendsPageState extends State<SleepTrendsPage> {
  DateTime? _selectedDay;

  Future<void> _openClockPicker(BuildContext context, TrendCubit<SleepSessionInfo> cubit) async {
    HapticFeedback.lightImpact();
    final saved = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => const _SleepEntrySheet(),
    );
    if (saved == true) {
      await cubit.load();
      try {
        await sl<HomeWidgetService>().refresh();
      } catch (_) {}
    }
  }

  Future<void> _openDatePicker(BuildContext context, TrendCubit<SleepSessionInfo> cubit) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  String _getInsightText({
    required double avgHours,
    required int goalMinutes,
    required SleepStats? stats,
    required List<SleepSessionInfo> logs,
  }) {
    if (logs.isEmpty) {
      return 'Log your sleep using the button below to start tracking your sleep cycles, recovery trends, and circadian insights.';
    }

    final goalHours = goalMinutes / 60.0;

    if (stats != null && stats.nightsLogged > 0) {
      final debtMinutes = stats.totalSleepDebt.inMinutes;

      if (debtMinutes > 90) {
        final debtStr = formatDashboardDuration(stats.totalSleepDebt);
        return 'You have accumulated $debtStr of sleep debt this week. Consider winding down 30–45 minutes earlier tonight to restore optimal cognitive alertness.';
      }

      if (stats.averageScore >= 85) {
        return 'Great sleep quality! Your average recovery score is ${stats.averageScore}% with steady restorative sleep. Keep this consistent bedtime rhythm.';
      }

      if (stats.consistencyScore < 70) {
        return 'Your bedtime routine varied across recent nights (Consistency: ${stats.consistencyScore}%). Going to bed within a 30-minute window significantly enhances REM and deep sleep stages.';
      }

      if (avgHours < goalHours - 0.75) {
        return 'Your 7-day average of ${avgHours.toStringAsFixed(1)}h is below your target of ${goalHours.toStringAsFixed(1)}h. Adding 30 minutes of screen-free relaxation before bed can help bridge the gap.';
      }

      if (avgHours >= goalHours - 0.5 && avgHours <= goalHours + 1.0) {
        return 'Your rest duration closely aligns with your ${goalHours.toStringAsFixed(1)}h nightly target. Maintaining this steady schedule supports physical recovery and all-day energy.';
      }
    }

    if (avgHours >= 7.0 && avgHours <= 9.0) {
      return 'Your sleep duration is in a healthy range (${avgHours.toStringAsFixed(1)}h). Going to bed at similar times helps your body maintain rhythm.';
    } else if (avgHours < 7.0) {
      return 'You are averaging ${avgHours.toStringAsFixed(1)}h of rest this week. Winding down 30 minutes earlier helps recover sleep debt.';
    } else {
      return 'Your sleep duration is averaging ${avgHours.toStringAsFixed(1)}h. Rest is essential; consistent wake times support steady daytime energy.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sleep = sl<SleepService>();

    return BlocProvider(
      create: (_) => TrendCubit<SleepSessionInfo>(sl<TrendsService>().sleep)..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<TrendCubit<SleepSessionInfo>>();

          return AppScaffold(
            header: AppPageHeader(
              title: 'Sleep',
              action: AppHeaderAction(
                icon: const Icon(Icons.calendar_month_rounded),
                onTap: () => _openDatePicker(context, cubit),
              ),
            ),
            bottomBar: AppPrimaryButton(
              label: 'Log sleep with Clock',
              leadingIcon: const Icon(Icons.bedtime_rounded, size: AppDimens.iconMd),
              onTap: () => _openClockPicker(context, cubit),
            ),
            onRefresh: () async {
              await cubit.load();
              try {
                await sl<HomeWidgetService>().refresh();
              } catch (_) {}
            },
            body: BlocBuilder<TrendCubit<SleepSessionInfo>, TrendState<SleepSessionInfo>>(
              builder: (context, state) {
                final data = state.data;
                if (data == null) {
                  if (state.error != null) {
                    return SizedBox(
                      height: 300,
                      child: LoadErrorView(onRetry: cubit.load),
                    );
                  }
                  return const SizedBox(
                    height: 300,
                    child: Center(child: VitalUpLoader()),
                  );
                }

                final v = context.vColors;
                final now = DateTime.now();

                // Compute selected day duration & matching session
                final selectedDate = _selectedDay ?? now;
                final isTodaySelected = isSameDay(selectedDate, now);

                DailyPoint? selectedPoint;
                for (final p in data.series.points) {
                  if (isSameDay(p.day, selectedDate)) {
                    selectedPoint = p;
                    break;
                  }
                }

                SleepSessionInfo? selectedSession;
                for (final log in data.logs) {
                  if (isSameDay(log.wakeTime, selectedDate) || isSameDay(log.bedTime, selectedDate)) {
                    selectedSession = log;
                    break;
                  }
                }

                // If today has no direct value in points, check logs for last night
                double displayedHours = selectedPoint?.value ?? 0.0;
                if (displayedHours <= 0 && isTodaySelected && data.logs.isNotEmpty) {
                  displayedHours = data.logs.first.duration.inMinutes / 60.0;
                  selectedSession ??= data.logs.first;
                }

                final displayedDurationStr = displayedHours > 0
                    ? SleepTrendsPage.formatHours(displayedHours)
                    : (selectedSession != null
                        ? formatDashboardDuration(selectedSession.duration)
                        : (isTodaySelected && data.logs.isNotEmpty
                            ? formatDashboardDuration(data.logs.first.duration)
                            : '0h 00m'));

                final todayLabel = isTodaySelected
                    ? 'TODAY'
                    : DateFormat('EEEE, d MMM').format(selectedDate).toUpperCase();

                final avgHours = data.series.average ?? (displayedHours > 0 ? displayedHours : 7.5);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. TODAY Duration Card (Figma Style)
                    AppCard(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space20,
                        vertical: AppDimens.space16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                todayLabel,
                                style: context.text.labelSmall?.copyWith(
                                  color: v.grayText,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  fontSize: 11,
                                ),
                              ),
                              if (selectedSession != null)
                                Flexible(
                                  child: Text(
                                    '${DateFormat.jm().format(selectedSession.bedTime)} – ${DateFormat.jm().format(selectedSession.wakeTime)}',
                                    style: context.text.labelSmall?.copyWith(
                                      color: v.grayText,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.space8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  displayedDurationStr,
                                  style: context.text.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 34,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openClockPicker(context, cubit),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppDimens.space8),
                                    child: SvgPicture.asset(
                                      'assets/icons/edit.svg',
                                      width: AppDimens.iconLg,
                                      height: AppDimens.iconLg,
                                      colorFilter: v.grayText != null ? ColorFilter.mode(v.grayText!, BlendMode.srcIn) : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.space16),

                    // 2. 7-DAY TREND Bar Chart (Figma Style)
                    _Figma7DayTrendCard(
                      series: data.series,
                      logs: data.logs,
                      selectedDay: _selectedDay,
                      onSelectDay: (day) => setState(() => _selectedDay = day),
                    ),

                    const SizedBox(height: AppDimens.space16),

                    // 3. INSIGHTS Gradient Card with actual dynamic insights
                    FutureBuilder<SleepStats>(
                      future: sleep.getWeeklyStats(),
                      builder: (context, statsSnap) {
                        final stats = statsSnap.data;
                        final insight = _getInsightText(
                          avgHours: avgHours,
                          goalMinutes: sleep.getGoalMinutes(),
                          stats: stats,
                          logs: data.logs,
                        );

                        return _FigmaInsightsCard(insight: insight);
                      },
                    ),

                    const SizedBox(height: AppDimens.sectionGap),

                    // 5. Nights & Quality Logs List
                    Text('Nights & Quality', style: context.text.headlineSmall),
                    const SizedBox(height: AppDimens.cardGap),

                    if (data.logs.isEmpty)
                      const AppInfoNote(message: 'Nothing logged in this period yet.')
                    else
                      for (final night in data.logs) ...[
                        _buildNightLogTile(context, night),
                        const SizedBox(height: AppDimens.space8),
                      ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNightLogTile(BuildContext context, SleepSessionInfo night) {
    final time = DateFormat.jm();
    final score = night.sleepScore;
    Color scoreColor;
    if (score >= 85) {
      scoreColor = AppColors.success;
    } else if (score >= 70) {
      scoreColor = AppColors.teal;
    } else if (score >= 50) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    return TrendLogTile(
      icon: night.source == SleepDataSource.healthStore
          ? Icons.watch_rounded
          : Icons.bedtime_rounded,
      color: scoreColor,
      title: DateFormat('EEE d MMM').format(night.wakeTime),
      subtitle: '${time.format(night.bedTime)} – ${time.format(night.wakeTime)}'
          ' · Score: $score% (${night.scoreCategory})',
      trailing: formatDashboardDuration(night.duration),
    );
  }
}

/// 7-DAY TREND card matching the Figma design:
/// - 7 vertical bars (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
/// - Gray bars for past days, vibrant green for the active day
/// - Flat bottom corners (removed bottom-left and bottom-right corner radius)
/// - Click or keep pressing (tap/long-press) to view sleep start & end time
class _Figma7DayTrendCard extends StatelessWidget {
  final TrendSeries series;
  final List<SleepSessionInfo> logs;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  const _Figma7DayTrendCard({
    required this.series,
    required this.logs,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Prepare 7 days of the week ending today
    final points = series.points.length >= 7
        ? series.points.sublist(series.points.length - 7)
        : series.points;

    // Calculate maximum duration to scale bars proportionally
    double maxHours = 9.0;
    for (final p in points) {
      if (p.value != null && p.value! > maxHours) {
        maxHours = p.value!;
      }
    }
    maxHours = maxHours.clamp(8.0, 12.0);

    const maxBarHeight = 120.0;
    const minBarHeight = 18.0;

    // Find session for selected day
    final activeDate = selectedDay ?? now;
    SleepSessionInfo? activeSession;
    for (final log in logs) {
      if (isSameDay(log.wakeTime, activeDate) || isSameDay(log.bedTime, activeDate)) {
        activeSession = log;
        break;
      }
    }

    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-DAY TREND',
                style: context.text.labelSmall?.copyWith(
                  color: v.grayText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),

            ],
          ),
          const SizedBox(height: AppDimens.space20),
          SizedBox(
            height: 155,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < points.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: _buildBarColumn(
                      context: context,
                      point: points[i],
                      maxHours: maxHours,
                      maxBarHeight: maxBarHeight,
                      minBarHeight: minBarHeight,
                      now: now,
                      isDark: isDark,
                      v: v,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarColumn({
    required BuildContext context,
    required DailyPoint point,
    required double maxHours,
    required double maxBarHeight,
    required double minBarHeight,
    required DateTime now,
    required bool isDark,
    required dynamic v,
  }) {
    final isToday = isSameDay(point.day, now);
    final isSelected = selectedDay != null && isSameDay(point.day, selectedDay!);
    final dayName = DateFormat('E').format(point.day); // Sun, Mon, Tue, etc.

    // Match sleep session for this bar
    SleepSessionInfo? session;
    for (final log in logs) {
      if (isSameDay(log.wakeTime, point.day) || isSameDay(log.bedTime, point.day)) {
        session = log;
        break;
      }
    }

    final hours = point.value ?? (session != null ? session.duration.inMinutes / 60.0 : 0.0);
    final fraction = (hours / maxHours).clamp(0.0, 1.0);
    final barHeight = hours > 0
        ? (minBarHeight + (maxBarHeight - minBarHeight) * fraction)
        : (minBarHeight * 0.6);

    // Figma colors: Gray for previous days, vibrant green (#22C55E) for active/today
    final barColor = isToday
        ? AppColors.success
        : isSelected
            ? AppColors.primary
            : (isDark ? const Color(0xFF334155) : const Color(0xFFC4CBD1));

    final tooltipMessage = session != null
        ? '${DateFormat('EEE d MMM').format(point.day)}: ${DateFormat.jm().format(session.bedTime)} – ${DateFormat.jm().format(session.wakeTime)} (${SleepTrendsPage.formatHours(hours)})'
        : (hours > 0
            ? '${DateFormat('EEE d MMM').format(point.day)}: ${SleepTrendsPage.formatHours(hours)}'
            : '${DateFormat('EEE d MMM').format(point.day)}: No sleep logged');

    return Tooltip(
      message: tooltipMessage,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelectDay(point.day);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onSelectDay(point.day);
        },
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimens.radiusSm),
          topRight: Radius.circular(AppDimens.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: maxBarHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: barColor,
                    // Flat bottom corners (removed bottom-left and bottom-right corner radius)
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dayName,
                style: context.text.bodySmall?.copyWith(
                  color: isToday ? context.colors.onSurface : v.grayText,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// INSIGHTS gradient card matching the Figma design:
/// Soft cyan/teal gradient background with teal header and readable typography.
class _FigmaInsightsCard extends StatelessWidget {
  final String insight;

  const _FigmaInsightsCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0E3D48).withValues(alpha: 0.7),
                  const Color(0xFF11382A).withValues(alpha: 0.6),
                ]
              : [
                  const Color(0xFFE0F7FA).withValues(alpha: 0.85),
                  const Color(0xFFE8F5E9).withValues(alpha: 0.65),
                ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1E525E)
              : const Color(0xFFB2EBF2).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blueGrey).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'INSIGHTS',
                style: context.text.labelSmall?.copyWith(
                  color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0D9488),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space10),
          Text(
            insight,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.9),
              height: 1.45,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bed / wake time interactive circular clock picker for last night
class _SleepEntrySheet extends StatefulWidget {
  const _SleepEntrySheet();

  @override
  State<_SleepEntrySheet> createState() => _SleepEntrySheetState();
}

class _SleepEntrySheetState extends State<_SleepEntrySheet> {
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wake = today.add(Duration(hours: _wake.hour, minutes: _wake.minute));
    var bed = today.add(Duration(hours: _bed.hour, minutes: _bed.minute));
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    await sl<SleepService>().saveManualEntry(bed, wake);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Log last night', style: context.text.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space12),
            CircularSleepClockPicker(
              initialBedTime: _bed,
              initialWakeTime: _wake,
              onChanged: (b, w) {
                setState(() {
                  _bed = b;
                  _wake = w;
                });
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Save Sleep',
              isLoading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
