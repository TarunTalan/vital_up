import 'dart:math';

/// A feature worth knowing about, told once in a notification ("feature
/// tips"). Shown only to users who haven't used it ([usedRoutes]).
class FeatureTip {
  final String id;
  final String title;
  final String body;

  /// Opened by a tap (a route name in `notificationLinkableRoutes`); null
  /// opens the app.
  final String? route;

  /// Visiting any of these marks the feature as used: no tip then.
  final Set<String> usedRoutes;

  /// Drawn as the notification's large icon (SVG, tinted).
  final String iconAsset;

  const FeatureTip({
    required this.id,
    required this.title,
    required this.body,
    required this.iconAsset,
    this.route,
    this.usedRoutes = const {},
  });
}

/// Every tip, at most one a week and each once ever. Short, plain, no
/// emojis or exclamation marks; the title is a hook, the body says what to
/// do.
const List<FeatureTip> featureTips = [
  FeatureTip(
    id: 'offline_maps',
    title: 'Heading off-grid?',
    body: "Save a trail's map before you go. Workouts track without signal.",
    route: 'offline-maps',
    usedRoutes: {'offline-maps', 'offline-map-picker'},
    iconAsset: 'assets/icons/vita/vita_person_run.svg',
  ),
  FeatureTip(
    id: 'home_widgets',
    title: 'Your day at a glance',
    body:
        'Add a VitalUp widget to see water, steps and sleep on your home '
        'screen.',
    route: 'home-widgets',
    usedRoutes: {'home-widgets', 'custom-widget-builder'},
    iconAsset: 'assets/icons/nav/home.svg',
  ),
  FeatureTip(
    id: 'launcher_shortcuts',
    title: 'One tap faster',
    body:
        'Long-press the VitalUp icon to start a workout, scan food or log '
        'water.',
    iconAsset: 'assets/icons/ui/flash.svg',
  ),
  FeatureTip(
    id: 'health_report',
    title: 'Seeing a doctor soon?',
    body:
        'Share a clear report of your sleep, weight and activity in two '
        'taps.',
    route: 'health-report',
    usedRoutes: {'health-report'},
    iconAsset: 'assets/icons/vita/vita_pulse.svg',
  ),
  FeatureTip(
    id: 'diet_plan',
    title: 'Meals that fit your goal',
    body:
        'Vita can plan a day of meals around your goal and the foods you '
        'like.',
    route: 'vita-diet-plan',
    usedRoutes: {
      'vita-diet-plan',
      'diet-plan-prefs',
      'diet-plan-mode',
      'diet-plan-result',
    },
    iconAsset: 'assets/icons/vita/vita_fork_knife.svg',
  ),
  FeatureTip(
    id: 'stress_guide',
    title: 'Take a breather',
    body: "Vita's stress guide has quick ways to unwind after a long day.",
    route: 'vita-stress',
    usedRoutes: {'vita-stress', 'stress-trends'},
    iconAsset: 'assets/icons/vita/vita_person_tai_chi.svg',
  ),
  FeatureTip(
    id: 'activity_calendar',
    title: 'Your month in one view',
    body:
        'See the days you moved, rested and ate well on your activity '
        'calendar.',
    route: 'activity-calendar',
    usedRoutes: {'activity-calendar'},
    iconAsset: 'assets/icons/trackers/activity.svg',
  ),
  FeatureTip(
    id: 'reminders',
    title: 'Nudges on your schedule',
    body: 'Set reminders for water, meals and bedtime at times that suit you.',
    route: 'reminders',
    usedRoutes: {'reminders'},
    iconAsset: 'assets/icons/vita/vita_chat_dots.svg',
  ),
  FeatureTip(
    id: 'challenges',
    title: 'Better with a friend',
    body: 'Start a 7-day challenge and see who moves more.',
    route: 'challenges',
    usedRoutes: {'challenges'},
    iconAsset: 'assets/icons/gamification/medal.svg',
  ),
];

/// When the next tip goes out (pure, unit-tested).
abstract final class FeatureTipRules {
  /// New users settle in first.
  static const int daysAfterInstall = 3;

  /// At most one tip a week.
  static const int daysBetweenTips = 7;

  /// Sent at a random time in the afternoon or early evening, never at
  /// night or first thing.
  static const int earliestHour = 11;
  static const int latestHour = 19;

  /// The tip to send next and when, or null (none left, or all used).
  /// [installedAt]: first time the app ran tips; [lastTipAt]: the last one
  /// sent. Days are calendar days in local time (daylight saving safe).
  static ({FeatureTip tip, DateTime at})? next({
    required DateTime now,
    required DateTime installedAt,
    DateTime? lastTipAt,
    required Set<String> shown,
    required Set<String> usedRoutes,
    List<FeatureTip> tips = featureTips,
    Random? random,
  }) {
    final eligible = [
      for (final tip in tips)
        if (!shown.contains(tip.id) && !tip.usedRoutes.any(usedRoutes.contains))
          tip,
    ];
    if (eligible.isEmpty) return null;
    final rng = random ?? Random();
    final tip = eligible[rng.nextInt(eligible.length)];

    DateTime day(DateTime d, int plus) =>
        DateTime(d.year, d.month, d.day + plus);
    var earliest = day(installedAt, daysAfterInstall);
    if (lastTipAt != null) {
      final afterLast = day(lastTipAt, daysBetweenTips);
      if (afterLast.isAfter(earliest)) earliest = afterLast;
    }
    final today = day(now, 0);
    // Today only with at least an hour of the window left.
    final lastStartToday = DateTime(
      now.year,
      now.month,
      now.day,
      latestHour - 1,
    );
    var date = earliest.isAfter(today) ? earliest : today;
    if (date == today && now.isAfter(lastStartToday)) date = day(today, 1);

    var from = DateTime(date.year, date.month, date.day, earliestHour);
    final until = DateTime(date.year, date.month, date.day, latestHour);
    if (date == today) {
      final soonest = now.add(const Duration(minutes: 30));
      if (soonest.isAfter(from)) from = soonest;
    }
    final minutes = max(1, until.difference(from).inMinutes);
    return (tip: tip, at: from.add(Duration(minutes: rng.nextInt(minutes))));
  }
}
