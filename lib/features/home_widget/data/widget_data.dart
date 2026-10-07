import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/goal_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/pages/water_trends_page.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Android providers, by class name (android/.../MetricsWidget.kt etc.).
/// Each size the app offers is its own provider, because Android pins a
/// widget at its provider's default size (see WidgetSizes.kt).
abstract final class WidgetProviders {
  static const _pkg = 'com.tarun_siddhi.vital_up';

  static const todaySmall = '$_pkg.TodaySmallWidgetProvider';
  static const today = '$_pkg.VitalUpWidgetProvider';
  static const todayLarge = '$_pkg.TodayLargeWidgetProvider';
  static const todayXLarge = '$_pkg.TodayXLargeWidgetProvider';

  static const customSmall = '$_pkg.CustomSmallWidgetProvider';
  static const custom = '$_pkg.CustomWidgetProvider';
  static const customLarge = '$_pkg.CustomLargeWidgetProvider';
  static const customXLarge = '$_pkg.CustomXLargeWidgetProvider';

  static const water = '$_pkg.HydrationWidgetProvider';
  static const waterWide = '$_pkg.WaterWideWidgetProvider';

  static const moodBar = '$_pkg.MoodBarWidgetProvider';
  static const mood = '$_pkg.MoodWidgetProvider';

  static const shortcutsSmall = '$_pkg.ShortcutsSmallWidgetProvider';
  static const shortcuts = '$_pkg.QuickShortcutsWidgetProvider';

  static const all = [
    todaySmall,
    today,
    todayLarge,
    todayXLarge,
    customSmall,
    custom,
    customLarge,
    customXLarge,
    water,
    waterWide,
    moodBar,
    mood,
    shortcutsSmall,
    shortcuts,
  ];

  /// The custom widget in every size (its settings changed).
  static const customAll = [customSmall, custom, customLarge, customXLarge];
}

/// What a metric widget slot can show. [id] is the key the native widgets
/// read (`m_<id>_value` and so on).
enum WidgetMetric {
  activity('activity', 'Activity', TrackerMetric.activity),
  calories('calories', 'Calories', TrackerMetric.nutrition),
  water('water', 'Water', TrackerMetric.water),
  sleep('sleep', 'Sleep', TrackerMetric.sleep),
  mood('mood', 'Mood', TrackerMetric.mood),
  weight('weight', 'Weight', TrackerMetric.weight);

  final String id;
  final String title;
  final TrackerMetric tracker;
  const WidgetMetric(this.id, this.title, this.tracker);

  Color get color => tracker.color;
  String get route => tracker.route;

  /// Same shapes as the native vector icons (wg_ic_*.xml).
  IconData get icon => switch (this) {
    activity => Icons.directions_walk_rounded,
    calories => Icons.restaurant_rounded,
    water => Icons.water_drop_rounded,
    sleep => Icons.bedtime_rounded,
    mood => Icons.sentiment_satisfied_rounded,
    weight => Icons.monitor_weight_rounded,
  };

  static WidgetMetric? byId(String id) =>
      values.where((m) => m.id == id).firstOrNull;

  /// Today's widget: the four figures of Home's Today card.
  static const today = [activity, calories, water, sleep];
}

/// Mood faces for check-in levels 1 (very calm) to 5 (very stressed); the
/// native faces are the same Material sentiment shapes.
IconData moodIcon(int level) => switch (level) {
  1 => Icons.sentiment_very_satisfied_rounded,
  2 => Icons.sentiment_satisfied_rounded,
  3 => Icons.sentiment_neutral_rounded,
  4 => Icons.sentiment_dissatisfied_rounded,
  5 => Icons.sentiment_very_dissatisfied_rounded,
  _ => Icons.sentiment_satisfied_rounded,
};

Color moodColor(int level) =>
    AppColors.stressLevels[(level - 1).clamp(
      0,
      AppColors.stressLevels.length - 1,
    )];

/// One metric as a widget shows it. Everything is display-ready, so the
/// home screen and the in-app preview render identical text.
class MetricTile {
  final WidgetMetric metric;
  final String label;
  final String value;
  final String detail;

  /// 0-100, or null when the metric has no goal to measure against.
  final int? progress;
  final Color color;

  const MetricTile({
    required this.metric,
    required this.label,
    required this.value,
    required this.detail,
    required this.progress,
    required this.color,
  });
}

/// The raw numbers behind the widgets. Saved alongside the display text so
/// a background refresh can replace what it can read locally (water, meals,
/// mood, weight) and rebuild the rest from the last full refresh.
class WidgetInputs {
  final bool signedIn;

  /// Local date (yyyy-MM-dd) the daily figures belong to.
  final String day;

  final String? activityMetric;
  final double? activityCurrent;
  final double? activityTarget;

  final int? caloriesEaten;
  final int? caloriesGoal;

  final int? waterMl;
  final int waterGoalMl;

  final int? sleepMinutes;
  final int sleepGoalMinutes;

  final int? moodLevel;
  final DateTime? moodAt;

  final double? weightKg;
  final DateTime? weightAt;
  final String weightUnit;

  const WidgetInputs({
    required this.signedIn,
    required this.day,
    this.activityMetric,
    this.activityCurrent,
    this.activityTarget,
    this.caloriesEaten,
    this.caloriesGoal,
    this.waterMl,
    this.waterGoalMl = 2500,
    this.sleepMinutes,
    this.sleepGoalMinutes = 480,
    this.moodLevel,
    this.moodAt,
    this.weightKg,
    this.weightAt,
    this.weightUnit = 'kg',
  });

  static String dayOf(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  WidgetInputs copyWith({
    bool? signedIn,
    String? day,
    int? waterMl,
    int? caloriesEaten,
    int? moodLevel,
    DateTime? moodAt,
    bool clearMood = false,
    double? weightKg,
    DateTime? weightAt,
  }) => WidgetInputs(
    signedIn: signedIn ?? this.signedIn,
    day: day ?? this.day,
    activityMetric: activityMetric,
    activityCurrent: activityCurrent,
    activityTarget: activityTarget,
    caloriesEaten: caloriesEaten ?? this.caloriesEaten,
    caloriesGoal: caloriesGoal,
    waterMl: waterMl ?? this.waterMl,
    waterGoalMl: waterGoalMl,
    sleepMinutes: sleepMinutes,
    sleepGoalMinutes: sleepGoalMinutes,
    moodLevel: clearMood ? null : moodLevel ?? this.moodLevel,
    moodAt: clearMood ? null : moodAt ?? this.moodAt,
    weightKg: weightKg ?? this.weightKg,
    weightAt: weightAt ?? this.weightAt,
    weightUnit: weightUnit,
  );

  /// Yesterday's daily figures don't carry over: on a new day, totals the
  /// background can't re-read (activity, sleep) become unknown.
  WidgetInputs forDay(String today) => today == day
      ? this
      : WidgetInputs(
          signedIn: signedIn,
          day: today,
          activityMetric: activityMetric,
          activityTarget: activityTarget,
          caloriesGoal: caloriesGoal,
          waterGoalMl: waterGoalMl,
          sleepGoalMinutes: sleepGoalMinutes,
          weightKg: weightKg,
          weightAt: weightAt,
          weightUnit: weightUnit,
        );

  // --- Persistence (home_widget storage, "in_" keys) -----------------------

  static const _prefix = 'in_';

  Future<void> save() async {
    Future<void> put(String key, Object? value) =>
        HomeWidget.saveWidgetData('$_prefix$key', value);
    await Future.wait([
      put('day', day),
      put('activity_metric', activityMetric),
      put('activity_current', activityCurrent?.toString()),
      put('activity_target', activityTarget?.toString()),
      put('calories', caloriesEaten?.toString()),
      put('calories_goal', caloriesGoal?.toString()),
      put('water', waterMl?.toString()),
      put('water_goal', waterGoalMl.toString()),
      put('sleep', sleepMinutes?.toString()),
      put('sleep_goal', sleepGoalMinutes.toString()),
      put('mood', moodLevel?.toString()),
      put('mood_at', moodAt?.toIso8601String()),
      put('weight', weightKg?.toString()),
      put('weight_at', weightAt?.toIso8601String()),
      put('weight_unit', weightUnit),
    ]);
  }

  static Future<WidgetInputs?> load() async {
    Future<String?> get(String key) =>
        HomeWidget.getWidgetData<String>('$_prefix$key');
    final day = await get('day');
    if (day == null) return null;
    final signedIn = await HomeWidget.getWidgetData<bool>('signed_in') ?? false;
    int? i(String? s) => s == null ? null : int.tryParse(s);
    double? d(String? s) => s == null ? null : double.tryParse(s);
    DateTime? t(String? s) => s == null ? null : DateTime.tryParse(s);
    return WidgetInputs(
      signedIn: signedIn,
      day: day,
      activityMetric: await get('activity_metric'),
      activityCurrent: d(await get('activity_current')),
      activityTarget: d(await get('activity_target')),
      caloriesEaten: i(await get('calories')),
      caloriesGoal: i(await get('calories_goal')),
      waterMl: i(await get('water')),
      waterGoalMl: i(await get('water_goal')) ?? 2500,
      sleepMinutes: i(await get('sleep')),
      sleepGoalMinutes: i(await get('sleep_goal')) ?? 480,
      moodLevel: i(await get('mood')),
      moodAt: t(await get('mood_at')),
      weightKg: d(await get('weight')),
      weightAt: t(await get('weight_at')),
      weightUnit: await get('weight_unit') ?? 'kg',
    );
  }
}

/// Turns [inputs] into what each widget shows. Pure, so the preview,
/// the app and the background isolate all produce the same text.
Map<WidgetMetric, MetricTile> buildTiles(WidgetInputs inputs) {
  final number = NumberFormat.decimalPattern();
  int? pct(num? value, num? goal) => value == null || goal == null || goal <= 0
      ? null
      : (value / goal * 100).round().clamp(0, 100);
  String time(DateTime t) => DateFormat.jm().format(t);

  final activityMetric = inputs.activityMetric == null
      ? null
      : GoalMetric.values
            .where((m) => m.name == inputs.activityMetric)
            .firstOrNull;

  MetricTile tile(
    WidgetMetric metric, {
    String? label,
    required String value,
    required String detail,
    int? progress,
    Color? color,
  }) => MetricTile(
    metric: metric,
    label: label ?? metric.title,
    value: value,
    detail: detail,
    progress: progress,
    color: color ?? metric.color,
  );

  final mood = inputs.moodLevel;
  final weightUnit = WeightUnit.fromCode(inputs.weightUnit);

  return {
    WidgetMetric.activity: activityMetric == null
        ? tile(
            WidgetMetric.activity,
            value: '—',
            detail: 'Set a goal',
            progress: 0,
          )
        : tile(
            WidgetMetric.activity,
            label: activityMetric.label,
            value: inputs.activityCurrent == null
                ? '—'
                : activityMetric.format(inputs.activityCurrent!),
            detail: inputs.activityTarget == null
                ? 'No goal'
                : 'of ${activityMetric.formatWithUnit(inputs.activityTarget!)}',
            progress:
                pct(inputs.activityCurrent ?? 0, inputs.activityTarget) ?? 0,
          ),
    WidgetMetric.calories: tile(
      WidgetMetric.calories,
      value: number.format(inputs.caloriesEaten ?? 0),
      detail: inputs.caloriesGoal == null
          ? 'kcal today'
          : 'of ${number.format(inputs.caloriesGoal)} kcal',
      progress: pct(inputs.caloriesEaten ?? 0, inputs.caloriesGoal) ?? 0,
    ),
    WidgetMetric.water: tile(
      WidgetMetric.water,
      value: WaterTrendsPage.formatMl((inputs.waterMl ?? 0).toDouble()),
      detail: 'of ${WaterTrendsPage.formatMl(inputs.waterGoalMl.toDouble())}',
      progress: pct(inputs.waterMl ?? 0, inputs.waterGoalMl) ?? 0,
    ),
    WidgetMetric.sleep: tile(
      WidgetMetric.sleep,
      label: 'Sleep',
      value: inputs.sleepMinutes == null
          ? '—'
          : formatDashboardDuration(Duration(minutes: inputs.sleepMinutes!)),
      detail: inputs.sleepMinutes == null
          ? 'Not logged'
          : 'of ${formatDashboardDuration(Duration(minutes: inputs.sleepGoalMinutes))}',
      progress: pct(inputs.sleepMinutes ?? 0, inputs.sleepGoalMinutes) ?? 0,
    ),
    WidgetMetric.mood: mood == null
        ? tile(WidgetMetric.mood, value: '—', detail: 'Not checked in')
        : tile(
            WidgetMetric.mood,
            value: StressCheckIn.labels[(mood - 1).clamp(0, 4)],
            detail: inputs.moodAt == null
                ? 'Checked in today'
                : 'Checked in ${time(inputs.moodAt!)}',
            color: moodColor(mood),
          ),
    WidgetMetric.weight: inputs.weightKg == null
        ? tile(WidgetMetric.weight, value: '—', detail: 'Not logged')
        : tile(
            WidgetMetric.weight,
            value: weightUnit.format(inputs.weightKg!),
            detail: inputs.weightAt == null
                ? 'Latest'
                : 'Logged ${DateFormat('d MMM').format(inputs.weightAt!)}',
          ),
  };
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Saves [inputs] and the tiles built from them, then redraws every widget.
Future<void> publishWidgets(WidgetInputs inputs, {DateTime? now}) async {
  final at = now ?? DateTime.now();
  final tiles = buildTiles(inputs);
  final writes = <Future<void>>[
    // Saving the new data ends the refresh: the spinner goes away.
    HomeWidget.saveWidgetData<String>('refreshing_since_ms', null),
    HomeWidget.saveWidgetData<bool>('signed_in', inputs.signedIn),
    HomeWidget.saveWidgetData<String>('snapshot_day', inputs.day),
    HomeWidget.saveWidgetData<String>(
      'updated_at_ms',
      at.millisecondsSinceEpoch.toString(),
    ),
    HomeWidget.saveWidgetData<String>(
      'today_metrics',
      WidgetMetric.today.map((m) => m.id).join(','),
    ),
    HomeWidget.saveWidgetData<int>('mood_level', inputs.moodLevel ?? 0),
    inputs.save(),
  ];
  for (final t in tiles.values) {
    final k = 'm_${t.metric.id}';
    writes.addAll([
      HomeWidget.saveWidgetData<String>('${k}_label', t.label),
      HomeWidget.saveWidgetData<String>('${k}_value', t.value),
      HomeWidget.saveWidgetData<String>('${k}_detail', t.detail),
      HomeWidget.saveWidgetData<int>('${k}_progress', t.progress ?? -1),
      HomeWidget.saveWidgetData<String>('${k}_color', _hex(t.color)),
      HomeWidget.saveWidgetData<String>('${k}_route', t.metric.route),
    ]);
  }
  await Future.wait(writes);
  await updateAllWidgets();
}

Future<void> updateAllWidgets() async {
  for (final p in WidgetProviders.all) {
    await HomeWidget.updateWidget(qualifiedAndroidName: p);
  }
}

/// Shows the refresh spinner on every widget until [publishWidgets] or
/// [endWidgetRefresh] (native expires it after 20 s as a backstop).
Future<void> startWidgetRefresh() async {
  await HomeWidget.saveWidgetData<String>(
    'refreshing_since_ms',
    DateTime.now().millisecondsSinceEpoch.toString(),
  );
  await updateAllWidgets();
}

/// A refresh failed: drop the spinner and keep the last data.
Future<void> endWidgetRefresh() async {
  await HomeWidget.saveWidgetData<String>('refreshing_since_ms', null);
  await updateAllWidgets();
}

// ---------------------------------------------------------------------------
// My metrics (custom widget) configuration
// ---------------------------------------------------------------------------

class CustomWidgetConfig {
  static const maxMetrics = 4;
  static const defaultTitle = 'My metrics';
  static const defaults = [WidgetMetric.water, WidgetMetric.activity];

  final String title;
  final List<WidgetMetric> metrics;

  const CustomWidgetConfig({
    this.title = defaultTitle,
    this.metrics = defaults,
  });

  CustomWidgetConfig copyWith({String? title, List<WidgetMetric>? metrics}) =>
      CustomWidgetConfig(
        title: title ?? this.title,
        metrics: metrics ?? this.metrics,
      );

  static Future<CustomWidgetConfig> load() async {
    final ids = await HomeWidget.getWidgetData<String>('custom_metrics');
    final title = await HomeWidget.getWidgetData<String>('custom_title');
    final metrics = ids
        ?.split(',')
        .map(WidgetMetric.byId)
        .whereType<WidgetMetric>()
        .toList();
    return CustomWidgetConfig(
      title: title == null || title.trim().isEmpty ? defaultTitle : title,
      metrics: metrics == null || metrics.isEmpty ? defaults : metrics,
    );
  }

  Future<void> save() async {
    await HomeWidget.saveWidgetData<String>(
      'custom_metrics',
      metrics.map((m) => m.id).join(','),
    );
    await HomeWidget.saveWidgetData<String>('custom_title', title.trim());
    for (final p in WidgetProviders.customAll) {
      await HomeWidget.updateWidget(qualifiedAndroidName: p);
    }
  }
}
