import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/point_goal.dart';

extension PointGoalMetric on PointGoal {
  /// The tracker whose goal editor sets this goal.
  TrackerMetric get metric => switch (this) {
    PointGoal.water => TrackerMetric.water,
    PointGoal.calories => TrackerMetric.nutrition,
    PointGoal.activity => TrackerMetric.activity,
  };
}

/// Arena card shown while a goal that points are scored against is
/// missing (water, calories, activity): those points can't be earned
/// until it's set. "Not now" hides it until another goal goes missing.
class PointGoalsNudge extends StatefulWidget {
  /// Spacing put under the card when it shows (none when it doesn't).
  final double gapBelow;

  const PointGoalsNudge({super.key, this.gapBelow = 0});

  /// The set of goals the user dismissed, e.g. "activity,water".
  static const hiddenKey = 'arena_goal_nudge_hidden';

  @override
  State<PointGoalsNudge> createState() => _PointGoalsNudgeState();
}

class _PointGoalsNudgeState extends State<PointGoalsNudge> {
  Set<PointGoal> _missing = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _keyOf(Set<PointGoal> goals) =>
      ([for (final g in goals) g.name]..sort()).join(',');

  Future<void> _load() async {
    Set<PointGoal> missing;
    try {
      missing = await sl<DailyMetricsCollector>().missingPointGoals();
    } catch (e) {
      debugPrint('Point goals unavailable: $e');
      missing = const {};
    }
    if (missing.isNotEmpty && sl.isRegistered<SharedPreferences>()) {
      final hidden = sl<SharedPreferences>().getString(
        PointGoalsNudge.hiddenKey,
      );
      if (hidden == _keyOf(missing)) missing = const {};
    }
    if (mounted) setState(() => _missing = missing);
  }

  Future<void> _setGoals() async {
    await context.pushNamed('my-goals');
    if (mounted) _load();
  }

  Future<void> _hide() async {
    final missing = _missing;
    setState(() => _missing = const {});
    await sl<SharedPreferences>().setString(
      PointGoalsNudge.hiddenKey,
      _keyOf(missing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missing;
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: missing.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(bottom: widget.gapBelow),
              child: _card(context, missing),
            ),
    );
  }

  Widget _card(BuildContext context, Set<PointGoal> missing) {
    final color = context.colors.primary;
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                color: color,
                icon: SvgPicture.asset(
                  TrackerIcons.goal,
                  width: AppDimens.iconSm,
                  height: AppDimens.iconSm,
                  colorFilter: ColorFilter.mode(
                    AppIconBadge.glyphColor(context, color),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text(
                  'Set goals to earn more points',
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            PointGoal.sentenceFor(missing),
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: _hide,
                style: TextButton.styleFrom(
                  foregroundColor: context.vColors.grayText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Not now'),
              ),
              CardLink(label: 'Set goals', onTap: _setGoals),
            ],
          ),
        ],
      ),
    );
  }
}
