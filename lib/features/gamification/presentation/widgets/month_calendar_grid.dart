import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

/// How a past day went, shown as the bar under its date.
enum CalendarDayGrade {
  /// Today or later: no bar.
  none,

  /// Past day with nothing logged: an empty track.
  empty,
  light,
  moderate,
  good,
}

/// Figma track/calender: a Sunday-first weekday row, then a 7-column grid
/// of glass day cells (8dp gaps), each with the date and a progress bar
/// coloured by its [CalendarDayGrade]. The selected day is filled with the
/// primary colour; days after today are greyed and can't be tapped.
///
/// Cells are square and take the width they get (44dp on the 412dp Figma
/// frame); with large text they grow taller so the date and bar stay whole.
class MonthCalendarGrid extends StatelessWidget {
  /// Any day in the month shown.
  final DateTime month;
  final DateTime selected;
  final CalendarDayGrade Function(DateTime day) gradeOf;
  final ValueChanged<DateTime> onSelect;

  /// Defaults to now; injectable for tests.
  final DateTime? today;

  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.gradeOf,
    required this.onSelect,
    this.today,
  });

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// Used when the short names don't all fit (narrow phones, large text).
  static const _narrowWeekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _gap = AppDimens.space8;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // Sunday is the first column: 0 = Sun ... 6 = Sat.
    final leading = DateTime(month.year, month.month, 1).weekday % 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - _gap * 6) / 7;
        // Date line (24dp at 1x) + gap + bar + border, grown with the text.
        final scaler = MediaQuery.textScalerOf(context);
        final dateLine = scaler.scale(AppTextStyles.body16.fontSize!) * 1.5;
        final content =
            dateLine +
            AppDimens.space4 +
            AppDimens.calendarBarHeight +
            AppDimens.space8;
        final cellHeight = math.max(cell, content);
        final weekdayStyle = context.text.bodySmall?.copyWith(
          color: context.vColors.grayText,
        );
        final weekdays =
            _weekdays.every(
              (d) => FitText.fits(
                context,
                TextSpan(text: d, style: weekdayStyle),
                cell,
              ),
            )
            ? _weekdays
            : _narrowWeekdays;
        // The bar keeps a little margin inside narrow cells.
        final barWidth = math.min(
          AppDimens.calendarBarWidth,
          cell - AppDimens.space8,
        );

        return Column(
          children: [
            SizedBox(
              height: context.textScaled(AppDimens.calendarWeekdayHeight),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: Center(
                        child: Text(
                          weekdays[i],
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: weekdayStyle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: _gap),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: _gap,
                crossAxisSpacing: _gap,
                mainAxisExtent: cellHeight,
              ),
              itemCount: leading + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final day = DateTime(
                  month.year,
                  month.month,
                  index - leading + 1,
                );
                final future = day.isAfter(todayStart);
                return _CalendarDay(
                  day: day,
                  selected: DateUtils.isSameDay(day, selected),
                  future: future,
                  grade: future ? CalendarDayGrade.none : gradeOf(day),
                  barWidth: barWidth,
                  onTap: future ? null : () => onSelect(day),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// One day of the month grid (Figma track/calender "Button").
class _CalendarDay extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool future;
  final CalendarDayGrade grade;
  final double barWidth;
  final VoidCallback? onTap;

  const _CalendarDay({
    required this.day,
    required this.selected,
    required this.future,
    required this.grade,
    required this.barWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final primary = context.colors.primary;
    // Figma fills: light and moderate days a short bar, good days most of it.
    final (Color? fill, double fraction) = switch (grade) {
      CalendarDayGrade.light => (AppColors.gradeBad, 0.4),
      CalendarDayGrade.moderate => (AppColors.gradeModerate, 0.4),
      CalendarDayGrade.good => (AppColors.gradeGood, 0.8),
      _ => (null, 0.0),
    };
    final showBar = grade != CalendarDayGrade.none && !selected;
    final radius = BorderRadius.circular(AppDimens.radiusToast);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: MaterialLocalizations.of(context).formatFullDate(day),
      excludeSemantics: true,
      child: Material(
        color: selected ? primary : v.glassFill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? primary : v.glassBorder!,
            width: AppDimens.borderThin,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                maxLines: 1,
                style: context.text.bodyLarge?.copyWith(
                  // Figma: 24dp line with the text centred in it (even
                  // leading), 4dp gap, 4dp bar.
                  height: 1.5,
                  leadingDistribution: TextLeadingDistribution.even,
                  color: selected
                      ? context.colors.onPrimary
                      : future
                      ? v.grayText
                      : context.colors.onSurface,
                ),
              ),
              if (showBar) ...[
                const SizedBox(height: AppDimens.space4),
                Container(
                  width: barWidth,
                  height: AppDimens.calendarBarHeight,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: v.track,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: fill == null
                      ? null
                      : FractionallySizedBox(
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusPill,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
