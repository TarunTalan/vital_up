import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/gamification/presentation/cubit/activity_calendar_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/month_calendar_grid.dart';

/// Activity Calendar Page displaying daily wellness metrics, expandable calendar,
/// and collapsible Move, Rest, Fuel, and Vitals categories.
class ActivityCalendarPage extends StatefulWidget {
  final DateTime? initialDate;

  const ActivityCalendarPage({super.key, this.initialDate});

  @override
  State<ActivityCalendarPage> createState() => _ActivityCalendarPageState();
}

class _ActivityCalendarPageState extends State<ActivityCalendarPage> {
  bool _isCalendarOpen = true;

  // Collapsible category state
  bool _moveExpanded = true;
  bool _restExpanded = true;
  bool _fuelExpanded = true;
  bool _vitalsExpanded = true;

  void _previousMonth(BuildContext context) {
    final cubit = context.read<ActivityCalendarCubit>();
    final current = cubit.state.focusedMonth;
    cubit.loadMonth(DateTime(current.year, current.month - 1, 1));
  }

  void _nextMonth(BuildContext context) {
    final cubit = context.read<ActivityCalendarCubit>();
    final current = cubit.state.focusedMonth;
    cubit.loadMonth(DateTime(current.year, current.month + 1, 1));
  }

  void _toggleCalendar() {
    setState(() {
      _isCalendarOpen = !_isCalendarOpen;
    });
  }

  // Returns completion status for day bar indicator:
  // -1 = Future/Today (No bar), 0 = No progress, 1 = Light (Red), 2 = Moderate (Orange), 3 = Good (Green)
  int _getDayStatus(DateTime date, ActivityCalendarState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (date.isAfter(today) || date.isAtSameMomentAs(today)) {
      return -1; // Future or Today
    }

    final metrics = state.monthMetrics[date];
    if (metrics == null) return 0; // No data yet

    int score = 0;
    if (metrics.activeMinutes > 20) score++;
    if (metrics.sleepHours > 6) score++;
    if (metrics.waterLogs > 0 || metrics.foodLogs > 0) score++;

    if (score == 0 && metrics.steps > 1000) return 1;
    if (score == 0) return 0;
    if (score == 1) return 1;
    if (score == 2) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityCalendarCubit, ActivityCalendarState>(
      builder: (context, state) {
        final metrics = state.selectedMetrics;
        final activeMins = metrics?.activeMinutes ?? 0;
        final steps = metrics?.steps ?? 0;
        final sleep = metrics?.sleepHours ?? 0.0;
        final water = metrics?.waterLogs ?? 0;
        final nutrition =
            metrics?.foodLogs ?? 0; // Using food logs count for now
        final stress = metrics?.moodLevel ?? 0;

        return AppScaffold(
          padBody: false,
          header: _buildHeader(context, state),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                context.safePadding.bottom + AppDimens.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Expandable Month Calendar Grid
                  AnimatedCrossFade(
                    firstChild: _buildCalendarView(context, state),
                    secondChild: const SizedBox.shrink(),
                    crossFadeState: _isCalendarOpen
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: AppDurations.medium,
                  ),

                  if (_isCalendarOpen)
                    const SizedBox(height: AppDimens.sectionGap),

                  // 2. Daily Wellness Summary Card
                  _buildDailySummaryCard(context, state),
                  const SizedBox(height: AppDimens.sectionGap),

                  // 3. Move Section (Activity, Steps)
                  _buildCategoryCard(
                    context,
                    title: 'MOVE',
                    isExpanded: _moveExpanded,
                    onToggle: () =>
                        setState(() => _moveExpanded = !_moveExpanded),
                    children: [
                      _MetricRow(
                        svgAsset: 'assets/icons/trackers/activity.svg',
                        iconBgColor: AppColors.success.withValues(alpha: 0.15),
                        iconColor: AppColors.success,
                        label: 'Activity',
                        value: '$activeMins min',
                        progress: (activeMins / 30).clamp(0.0, 1.0),
                        progressColor: AppColors.success,
                      ),
                      const SizedBox(height: AppDimens.space12),
                      _MetricRow(
                        svgAsset: 'assets/icons/trackers/step.svg',
                        iconBgColor: AppColors.success.withValues(alpha: 0.15),
                        iconColor: AppColors.success,
                        label: 'Steps',
                        value: '$steps',
                        progress: (steps / 10000).clamp(0.0, 1.0),
                        progressColor: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sectionGap),

                  // 4. Rest Section (Sleep, Screen time)
                  _buildCategoryCard(
                    context,
                    title: 'REST',
                    isExpanded: _restExpanded,
                    onToggle: () =>
                        setState(() => _restExpanded = !_restExpanded),
                    children: [
                      _MetricRow(
                        icon: Icons.bedtime_rounded,
                        iconBgColor: AppColors.success.withValues(alpha: 0.15),
                        iconColor: AppColors.success,
                        label: 'Sleep',
                        value: '${sleep.toStringAsFixed(1)}h',
                        progress: (sleep / 8.0).clamp(0.0, 1.0),
                        progressColor: AppColors.success,
                      ),
                      const SizedBox(height: AppDimens.space12),
                      _MetricRow(
                        icon: Icons.devices_rounded,
                        iconBgColor: AppColors.warning.withValues(alpha: 0.15),
                        iconColor: AppColors.warning,
                        label: 'Screen time',
                        value: '-',
                        progress: 0.0,
                        progressColor: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sectionGap),

                  // 5. Fuel Section (Nutrition, Water)
                  _buildCategoryCard(
                    context,
                    title: 'FUEL',
                    isExpanded: _fuelExpanded,
                    onToggle: () =>
                        setState(() => _fuelExpanded = !_fuelExpanded),
                    children: [
                      _MetricRow(
                        icon: Icons.restaurant_rounded,
                        iconBgColor: AppColors.error.withValues(alpha: 0.15),
                        iconColor: AppColors.error,
                        label: 'Nutrition',
                        value: '$nutrition logs',
                        progress: (nutrition / 3.0).clamp(0.0, 1.0),
                        progressColor: AppColors.error,
                      ),
                      const SizedBox(height: AppDimens.space12),
                      _MetricRow(
                        icon: Icons.water_drop_rounded,
                        iconBgColor: AppColors.error.withValues(alpha: 0.15),
                        iconColor: AppColors.error,
                        label: 'Water',
                        value: '$water glasses',
                        progress: (water / 8.0).clamp(0.0, 1.0),
                        progressColor: AppColors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sectionGap),

                  // 6. Vitals Section (Heart rate)
                  _buildCategoryCard(
                    context,
                    title: 'VITALS',
                    isExpanded: _vitalsExpanded,
                    onToggle: () =>
                        setState(() => _vitalsExpanded = !_vitalsExpanded),
                    children: [
                      _MetricRow(
                        icon: Icons.favorite_rounded,
                        iconBgColor: AppColors.success.withValues(alpha: 0.15),
                        iconColor: AppColors.success,
                        label: 'Stress check-in',
                        value: stress > 0 ? 'Level $stress' : '-',
                        progress: stress > 0 ? 1.0 : 0.0,
                        progressColor: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Custom top app bar matching the user design with Month Year and [<] [📅] [>]
  Widget _buildHeader(BuildContext context, ActivityCalendarState state) {
    final monthTitle = DateFormat('MMM y').format(state.focusedMonth);

    return AppPageHeader(
      title: monthTitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous Month Button
          _HeaderNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _previousMonth(context),
          ),
          const SizedBox(width: AppDimens.space6),

          // Calendar Toggle Button
          _HeaderNavButton(
            icon: Icons.calendar_month_rounded,
            isActive: _isCalendarOpen,
            onTap: _toggleCalendar,
          ),
          const SizedBox(width: AppDimens.space6),

          // Next Month Button
          _HeaderNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => _nextMonth(context),
          ),
        ],
      ),
    );
  }

  /// Figma track/calender month grid ([MonthCalendarGrid]).
  Widget _buildCalendarView(BuildContext context, ActivityCalendarState state) {
    return MonthCalendarGrid(
      month: state.focusedMonth,
      selected: state.selectedDate,
      gradeOf: (day) => switch (_getDayStatus(day, state)) {
        0 => CalendarDayGrade.empty,
        1 => CalendarDayGrade.light,
        2 => CalendarDayGrade.moderate,
        3 => CalendarDayGrade.good,
        _ => CalendarDayGrade.none,
      },
      onSelect: (day) => context.read<ActivityCalendarCubit>().selectDate(day),
    );
  }

  /// Daily summary card (e.g. "Light activity day with good rest...")
  Widget _buildDailySummaryCard(
    BuildContext context,
    ActivityCalendarState state,
  ) {
    if (state.failed) {
      return AppCard(
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Couldn't load this day.",
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.read<ActivityCalendarCubit>().selectDate(
                state.selectedDate,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    String message = "No data recorded for this day.";
    Color iconColor = AppColors.primary;
    IconData icon = Icons.insights_rounded;

    if (state.loading) {
      message = "Loading...";
    } else if (state.selectedMetrics != null) {
      final score = _getDayStatus(state.selectedDate, state);
      if (score == 3) {
        message = "Excellent day. You met most of your wellness goals.";
        iconColor = AppColors.gradeGood;
        icon = Icons.check_circle_rounded;
      } else if (score == 2) {
        message =
            "Good day. A few more healthy choices could boost your score.";
        iconColor = AppColors.gradeModerate;
        icon = Icons.trending_up_rounded;
      } else if (score == 1) {
        message = "Light activity day. Take it easy and try to get some rest.";
        iconColor = AppColors.gradeBad;
        icon = Icons.nature_people_rounded;
      } else {
        message = "No goals met on this day. Every little bit counts.";
        iconColor = context.vColors.grayText ?? AppColors.greyText;
        icon = Icons.info_outline_rounded;
      }
    }

    return AppCard(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(color: iconColor, icon: Icon(icon)),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppCaption('DAILY SUMMARY'),
                const SizedBox(height: AppDimens.space4),
                Text(
                  message,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurface,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsible category card for Move, Rest, Fuel, and Vitals
  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    final v = context.vColors;

    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Category Title and Arrow
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppCaption(title),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: AppDimens.iconMd,
                    color: v.grayText,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const SizedBox(height: AppDimens.space16),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String value;
  final double progress;
  final Color progressColor;

  const _MetricRow({
    this.icon,
    this.svgAsset,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.progress,
    required this.progressColor,
  }) : assert(icon != null || svgAsset != null);

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final onSurface = context.colors.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space12),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusToast),
        border: Border.all(color: v.glassBorder!, width: AppDimens.borderThin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Icon, Label, Value
          Row(
            children: [
              AppIconBadge(
                size: AppDimens.iconBadgeSmall,
                color: iconColor,
                icon: svgAsset != null
                    ? SvgPicture.asset(
                        svgAsset!,
                        width: AppDimens.iconSm,
                        height: AppDimens.iconSm,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(icon, size: AppDimens.iconSm, color: iconColor),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ),
              Text(
                value,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),

          // Horizontal Progress Bar
          AppProgressBar(
            value: progress,
            color: progressColor,
            trackColor: v.track,
          ),
        ],
      ),
    );
  }
}

class _HeaderNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _HeaderNavButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return SizedBox.square(
      dimension: AppDimens.headerActionSize,
      child: Material(
        color: isActive ? primary : context.vColors.primaryFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          side: BorderSide(
            color: isActive ? primary : context.vColors.primaryBorder!,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: AppDimens.iconLg,
              color: isActive ? context.colors.surface : primary,
            ),
          ),
        ),
      ),
    );
  }
}
