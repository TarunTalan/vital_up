import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/gamification/presentation/cubit/activity_calendar_cubit.dart';
/// Activity Calendar Page displaying daily wellness metrics, expandable calendar,
/// and collapsible Move, Rest, Fuel, and Vitals categories.
class ActivityCalendarPage extends StatefulWidget {
  final DateTime? initialDate;

  const ActivityCalendarPage({
    super.key,
    this.initialDate,
  });

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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
        final nutrition = metrics?.foodLogs ?? 0; // Using food logs count for now
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

              if (_isCalendarOpen) const SizedBox(height: AppDimens.sectionGap),

              // 2. Daily Wellness Summary Card
              _buildDailySummaryCard(context, state),
              const SizedBox(height: AppDimens.sectionGap),

              // 3. Move Section (Activity, Steps)
              _buildCategoryCard(
                context,
                title: 'MOVE',
                isExpanded: _moveExpanded,
                onToggle: () => setState(() => _moveExpanded = !_moveExpanded),
                children: [
                  _MetricRow(
                    icon: Icons.directions_run_rounded,
                    iconBgColor: AppColors.success.withValues(alpha: 0.15),
                    iconColor: AppColors.success,
                    label: 'Activity',
                    value: '$activeMins min',
                    progress: (activeMins / 30).clamp(0.0, 1.0),
                    progressColor: AppColors.success,
                  ),
                  const SizedBox(height: AppDimens.space12),
                  _MetricRow(
                    icon: Icons.directions_walk_rounded,
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
                onToggle: () => setState(() => _restExpanded = !_restExpanded),
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
                onToggle: () => setState(() => _fuelExpanded = !_fuelExpanded),
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
                onToggle: () => setState(() => _vitalsExpanded = !_vitalsExpanded),
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
    final monthTitle = DateFormat('MMM yyyy').format(state.focusedMonth);

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

  /// The month grid with weekdays, date buttons, status indicator bars, and selected highlight
  Widget _buildCalendarView(BuildContext context, ActivityCalendarState state) {
    final v = context.vColors;
    final year = state.focusedMonth.year;
    final month = state.focusedMonth.month;

    // Number of days in current focused month
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // Weekday of the first day (DateTime weekday: 1 = Mon ... 7 = Sun)
    // Design has Sunday as the first column: 0 = Sun, 1 = Mon ... 6 = Sat
    final firstDayWeekday = DateTime(year, month, 1).weekday % 7;

    const weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Weekday Labels Row
        Padding(
          padding: const EdgeInsets.only(
            top: AppDimens.space8,
            bottom: AppDimens.space16,
          ),
          child: Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: AppDimens.space8,
            crossAxisSpacing: AppDimens.space8,
            childAspectRatio: 0.95,
          ),
          itemCount: firstDayWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstDayWeekday) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - firstDayWeekday + 1;
            final cellDate = DateTime(year, month, dayNumber);
            final isSelected = _isSameDay(cellDate, state.selectedDate);
            final status = _getDayStatus(cellDate, state);

            // Bar indicator color based on status
            final barColor = switch (status) {
              0 => context.colors.onSurface.withValues(alpha: 0.15),
              1 => AppColors.error,
              2 => AppColors.warning,
              3 => AppColors.success,
              _ => Colors.transparent,
            };

            return InkWell(
              onTap: () {
                if (cellDate.isAfter(DateTime.now())) return;
                context.read<ActivityCalendarCubit>().selectDate(cellDate);
              },
              borderRadius: BorderRadius.circular(AppDimens.radiusToast),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : v.glassFill ?? AppColors.surfaceDarkElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: v.glassBorder!.withValues(alpha: 0.5),
                          width: AppDimens.borderThin,
                        ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: context.text.bodyMedium?.copyWith(
                        color: isSelected
                            ? context.colors.surface
                            : context.colors.onSurface,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (status >= 0) ...[
                      const SizedBox(height: 3),
                      Container(
                        width: 14,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Daily summary card (e.g. "Light activity day with good rest...")
  Widget _buildDailySummaryCard(BuildContext context, ActivityCalendarState state) {
    String message = "No data recorded for this day.";
    if (state.loading) {
      message = "Loading...";
    } else if (state.selectedMetrics != null) {
      final score = _getDayStatus(state.selectedDate, state);
      if (score == 3) {
        message = "Excellent day! You've met most of your wellness goals.";
      } else if (score == 2) {
        message = "Good day! A few more healthy choices could boost your score.";
      } else if (score == 1) {
        message = "Light activity day. Take it easy and try to get some rest.";
      } else {
        message = "No goals were met on this day. Remember, every little bit counts!";
      }
    }

    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Text(
        message,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurface,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
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
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Category Title and Arrow
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppDimens.radiusXs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: context.text.labelMedium?.copyWith(
                    color: v.grayText,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
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

          if (isExpanded) ...[
            const SizedBox(height: AppDimens.space12),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String value;
  final double progress;
  final Color progressColor;

  const _MetricRow({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.progress,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space10,
      ),
      decoration: BoxDecoration(
        color: v.glassFill ?? AppColors.surfaceDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: v.glassBorder!.withValues(alpha: 0.5),
          width: AppDimens.borderThin,
        ),
      ),
      child: Column(
        children: [
          // Top Row: Icon, Label, Value
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBgColor,
                ),
                child: Icon(icon, size: AppDimens.iconSm, color: iconColor),
              ),
              const SizedBox(width: AppDimens.space10),
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space10),

          // Horizontal Progress Bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: v.track ?? AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.02, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    ),
                  ),
                ),
              ),
            ),
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
