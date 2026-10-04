import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';

/// A rich GitHub/fitness-style activity calendar heatmap displaying daily XP
/// achievements, streak progression, and daily & weekly progress metrics.
class ActivityHeatmapCard extends StatefulWidget {
  const ActivityHeatmapCard({super.key});

  @override
  State<ActivityHeatmapCard> createState() => _ActivityHeatmapCardState();
}

class _ActivityHeatmapCardState extends State<ActivityHeatmapCard> {
  final ScrollController _scrollController = ScrollController();
  Map<String, int> _dailyPoints = {};
  Map<String, Map<ScoreCategory, int>> _dailyCategories = {};
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    // Scroll to the latest weeks after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final repo = sl<GamificationRepository>();
      final events = await repo.getHistory(days: 90);
      if (!mounted) return;

      final points = <String, int>{};
      final categories = <String, Map<ScoreCategory, int>>{};

      for (final e in events) {
        final key = DateFormat('yyyy-MM-dd').format(e.day);
        points[key] = (points[key] ?? 0) + e.points;
        categories.putIfAbsent(key, () => {});
        categories[key]![e.category] = (categories[key]![e.category] ?? 0) + e.points;
      }

      setState(() {
        _dailyPoints = points;
        _dailyCategories = categories;
        _selectedDate = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedDate = DateTime.now();
        });
      }
    }
  }

  int _getPointsForDate(DateTime date, GamificationState gameState) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday && gameState.todayTotal > 0) {
      return gameState.todayTotal;
    }
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _dailyPoints[key] ?? 0;
  }

  int _calculateThisWeekXp(GamificationState gameState) {
    final now = DateTime.now();
    // Start of current week (Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    var sum = 0;
    for (var i = 0; i <= now.weekday - 1; i++) {
      final day = monday.add(Duration(days: i));
      sum += _getPointsForDate(day, gameState);
    }
    return sum;
  }

  Color _getColorForPoints(int pts, BuildContext context, bool isToday) {
    final v = context.vColors;
    if (pts <= 0) {
      return isToday
          ? context.colors.primary.withValues(alpha: 0.15)
          : v.glassFill ?? AppColors.surfaceDarkElevated.withValues(alpha: 0.5);
    }
    if (pts < 20) {
      return context.colors.primary.withValues(alpha: 0.3);
    }
    if (pts < 40) {
      return context.colors.primary.withValues(alpha: 0.55);
    }
    if (pts < 60) {
      return context.colors.primary.withValues(alpha: 0.8);
    }
    return context.colors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final now = DateTime.now();

    return BlocBuilder<GamificationCubit, GamificationState>(
      builder: (context, gameState) {
        final stats = gameState.stats ?? PlayerStats.empty;
        final thisWeekXp = _calculateThisWeekXp(gameState);

        // Generate past 13 weeks of dates (ending this week on Sunday)
        // 7 rows: 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
        const totalWeeks = 13;
        final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
        final currentWeekMonday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: currentWeekday - 1));
        final startMonday = currentWeekMonday.subtract(const Duration(days: 7 * (totalWeeks - 1)));

        final selectedKey = _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : null;
        final selectedPoints = _selectedDate != null
            ? _getPointsForDate(_selectedDate!, gameState)
            : 0;
        final selectedCategories = selectedKey != null
            ? _dailyCategories[selectedKey] ?? const <ScoreCategory, int>{}
            : const <ScoreCategory, int>{};

        return AppCard(
          width: double.infinity,
          padding: AppDimens.cardPaddingCompact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Month / Subtitle Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimens.space6),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimens.radiusXs),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: AppDimens.iconSm,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(width: AppDimens.space8),
                      Text(
                        'Activity Heatmap',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('MMM yyyy').format(now),
                    style: context.text.labelSmall?.copyWith(
                      color: v.grayText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),

              // Calendar Heatmap Grid (Mon-Sun rows, 13 weeks columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Labels Column (M, W, F)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: AppDimens.space6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DayLabel('M'),
                        const SizedBox(height: 2),
                        _DayLabel(''),
                        const SizedBox(height: 2),
                        _DayLabel('W'),
                        const SizedBox(height: 2),
                        _DayLabel(''),
                        const SizedBox(height: 2),
                        _DayLabel('F'),
                        const SizedBox(height: 2),
                        _DayLabel(''),
                        const SizedBox(height: 2),
                        _DayLabel('S'),
                      ],
                    ),
                  ),

                  // Scrollable Grid of 13 Weeks
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var weekIdx = 0; weekIdx < totalWeeks; weekIdx++) ...[
                            Column(
                              children: [
                                for (var dayIdx = 0; dayIdx < 7; dayIdx++) ...[
                                  () {
                                    final cellDate = startMonday
                                        .add(Duration(days: weekIdx * 7 + dayIdx));
                                    final isFuture = cellDate.isAfter(now);
                                    final isToday = cellDate.year == now.year &&
                                        cellDate.month == now.month &&
                                        cellDate.day == now.day;
                                    final isSelected = _selectedDate != null &&
                                        cellDate.year == _selectedDate!.year &&
                                        cellDate.month == _selectedDate!.month &&
                                        cellDate.day == _selectedDate!.day;
                                    final pts = isFuture
                                        ? 0
                                        : _getPointsForDate(cellDate, gameState);
                                    final cellColor = isFuture
                                        ? Colors.transparent
                                        : _getColorForPoints(pts, context, isToday);

                                    return GestureDetector(
                                      onTap: isFuture
                                          ? null
                                          : () => setState(() => _selectedDate = cellDate),
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: cellColor,
                                          borderRadius: BorderRadius.circular(3),
                                          border: isSelected
                                              ? Border.all(
                                                  color: AppColors.white,
                                                  width: 1.5,
                                                )
                                              : isToday
                                                  ? Border.all(
                                                      color: context.colors.primary,
                                                      width: 1.5,
                                                    )
                                                  : Border.all(
                                                      color: isFuture
                                                          ? Colors.transparent
                                                          : v.glassBorder!.withValues(alpha: 0.3),
                                                      width: 0.5,
                                                    ),
                                          boxShadow: pts >= 60 && !isFuture
                                              ? [
                                                  BoxShadow(
                                                    color: context.colors.primary.withValues(alpha: 0.4),
                                                    blurRadius: 4,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    );
                                  }(),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.space10),

              // Legend (Less -> More)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap day for details',
                    style: context.text.bodySmall?.copyWith(
                      color: v.grayText,
                      fontSize: 10.5,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Less',
                        style: context.text.labelSmall?.copyWith(
                          color: v.grayText,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: AppDimens.space4),
                      _LegendBox(v.glassFill ?? AppColors.surfaceDark),
                      _LegendBox(context.colors.primary.withValues(alpha: 0.3)),
                      _LegendBox(context.colors.primary.withValues(alpha: 0.55)),
                      _LegendBox(context.colors.primary.withValues(alpha: 0.8)),
                      _LegendBox(context.colors.primary),
                      const SizedBox(width: AppDimens.space4),
                      Text(
                        'More',
                        style: context.text.labelSmall?.copyWith(
                          color: v.grayText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.space12),

              // Selected Day Inspector Strip
              if (_selectedDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space10,
                    vertical: AppDimens.space8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    border: Border.all(
                      color: v.glassBorder!,
                      width: AppDimens.borderThin,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedPoints > 0
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: AppDimens.iconSm,
                        color: selectedPoints > 0
                            ? context.colors.primary
                            : v.grayText,
                      ),
                      const SizedBox(width: AppDimens.space8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d').format(_selectedDate!),
                              style: context.text.labelSmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (selectedPoints > 0 && selectedCategories.isNotEmpty)
                              Text(
                                [
                                  for (final entry in selectedCategories.entries)
                                    '${entry.key.name}: +${entry.value}',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall?.copyWith(
                                  color: v.grayText,
                                  fontSize: 10.5,
                                ),
                              )
                            else if (selectedPoints > 0)
                              Text(
                                'Points earned from daily habits & workouts',
                                style: context.text.bodySmall?.copyWith(
                                  color: v.grayText,
                                  fontSize: 10.5,
                                ),
                              )
                            else
                              Text(
                                'No points earned on this day',
                                style: context.text.bodySmall?.copyWith(
                                  color: v.grayText,
                                  fontSize: 10.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: selectedPoints > 0
                              ? context.colors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                          border: Border.all(
                            color: selectedPoints > 0
                                ? context.colors.primary.withValues(alpha: 0.4)
                                : v.glassBorder!,
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: Text(
                          selectedPoints > 0 ? '+$selectedPoints XP' : '0 XP',
                          style: context.text.labelSmall?.copyWith(
                            color: selectedPoints > 0
                                ? context.colors.primary
                                : v.grayText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppDimens.space12),

              // Streak & Progress Quick Stats Pills Row
              Row(
                children: [
                  Expanded(
                    child: _HeatmapStatPill(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppColors.streak,
                      value: '${stats.streak} Days',
                      label: 'CURRENT STREAK',
                    ),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: _HeatmapStatPill(
                      icon: Icons.electric_bolt_rounded,
                      iconColor: context.colors.primary,
                      value: '$thisWeekXp XP',
                      label: 'THIS WEEK',
                    ),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: _HeatmapStatPill(
                      icon: Icons.emoji_events_rounded,
                      iconColor: AppColors.rankGold,
                      value: '${stats.longestStreak} Days',
                      label: 'BEST STREAK',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String text;

  const _DayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Center(
        child: Text(
          text,
          style: context.text.labelSmall?.copyWith(
            color: context.vColors.grayText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  final Color color;

  const _LegendBox(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _HeatmapStatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _HeatmapStatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.space8,
        horizontal: AppDimens.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: v.glassBorder!,
          width: AppDimens.borderThin,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppDimens.iconXs, color: iconColor),
              const SizedBox(width: AppDimens.space4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: v.grayText,
              fontWeight: FontWeight.w700,
              fontSize: 8.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
