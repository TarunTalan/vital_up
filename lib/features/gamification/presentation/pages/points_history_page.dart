import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/gamification/presentation/widgets/score_streak_card.dart';

final _points = NumberFormat.decimalPattern();

typedef _HistoryData = (PlayerStats, List<PointEvent>, List<PointRule>);

/// Lifetime points per category, the last 30 days of awards, and how each
/// action scores.
class PointsHistoryPage extends StatefulWidget {
  const PointsHistoryPage({super.key});

  @override
  State<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage> {
  late Future<_HistoryData> _data = _load();

  Future<_HistoryData> _load() {
    final repo = sl<GamificationRepository>();
    return (
      repo.getStats(),
      repo.getHistory(),
      repo.getRules(),
    ).wait.withLoadTimeout();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      onRefresh: () async => setState(() => _data = _load()),
      header: const AppPageHeader(title: 'Points'),
      body: FutureBuilder<_HistoryData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadErrorView(
              onRetry: () => setState(() => _data = _load()),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Padding(
              padding: EdgeInsets.only(top: AppDimens.space48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final (stats, events, rules) = data;
          final names = {for (final r in rules) r.source: r.name};
          final byDay = bucketByDay(events, (e) => e.day);
          final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LevelRing(stats: stats),
                  const SizedBox(width: AppDimens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_points.format(stats.totalPoints)} pts',
                          style: context.text.headlineSmall,
                        ),
                        Text(
                          'Level ${stats.level.level} · ${stats.level.title}',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.vColors.grayText,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space8),
                        StreakPill(streak: stats.streak),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.cardInnerGap),
              Row(
                children: [
                  for (final c in ScoreCategory.values) ...[
                    if (c != ScoreCategory.values.first)
                      const SizedBox(width: AppDimens.space8),
                    Expanded(
                      child: CategoryPointsTile(
                        category: c,
                        points: stats.pointsIn(c),
                        signed: false,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),
              Text('Last 30 days', style: context.text.titleMedium),
              const SizedBox(height: AppDimens.space12),
              if (days.isEmpty)
                const AppInfoNote(
                  message:
                      'No points yet. Log a meal, some water or your '
                      'mood to earn your first points.',
                ),
              for (final day in days) ...[
                _DayCard(day: day, events: byDay[day]!, names: names),
                const SizedBox(height: AppDimens.cardGap),
              ],
              const SizedBox(height: AppDimens.space12),
              Text('How to earn', style: context.text.titleMedium),
              const SizedBox(height: AppDimens.space12),
              for (final c in ScoreCategory.values)
                if (rules.any((r) => r.category == c && r.points > 0)) ...[
                  _RulesCard(
                    category: c,
                    rules: [
                      for (final r in rules)
                        if (r.category == c && r.points > 0) r,
                    ],
                  ),
                  const SizedBox(height: AppDimens.cardGap),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  final ScoreCategory category;

  const _CategoryDot(this.category);

  @override
  Widget build(BuildContext context) => Container(
    width: AppDimens.bulletDot,
    height: AppDimens.bulletDot,
    decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
  );
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<PointEvent> events;
  final Map<String, String> names;

  const _DayCard({
    required this.day,
    required this.events,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final total = events.fold<int>(0, (sum, e) => sum + e.points);
    final today = startOfDay(DateTime.now());
    final label = day == today
        ? 'Today'
        : day == DateTime(today.year, today.month, today.day - 1)
        ? 'Yesterday'
        : DateFormat('EEE, MMM d').format(day);
    final sorted = [...events]
      ..sort(
        (a, b) => a.category.index != b.category.index
            ? a.category.index.compareTo(b.category.index)
            : b.points.compareTo(a.points),
      );

    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: context.text.titleSmall)),
              Text(
                '+${_points.format(total)}',
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
              child: Row(
                children: [
                  _CategoryDot(e.category),
                  const SizedBox(width: AppDimens.space8),
                  Expanded(
                    child: Text(
                      names[e.source] ?? e.source,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '+${e.points}',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.vColors.grayText,
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

class _RulesCard extends StatelessWidget {
  final ScoreCategory category;
  final List<PointRule> rules;

  const _RulesCard({required this.category, required this.rules});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              category.iconAsset != null
                  ? GameIcon(
                      category.iconAsset!,
                      fallback: category.icon,
                      color: category.color,
                      size: AppDimens.iconMd,
                    )
                  : Icon(
                      category.icon,
                      color: category.color,
                      size: AppDimens.iconMd,
                    ),
              const SizedBox(width: AppDimens.space8),
              Text(category.label, style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Text(
                    '+${r.points} ${r.unit}'
                    '${r.dailyCap != null && r.dailyCap != r.points ? ' · max ${r.dailyCap}/day' : ''}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.grayText,
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
