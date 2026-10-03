import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/events/habit_events.dart';
import 'package:vital_up/core/router/app_router.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';
import 'package:vital_up/features/reminders/data/reminder_actions.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

/// Android provider classes for all 8 widget types
const providerMultiFeature = 'com.tarun_siddhi.vital_up.VitalUpWidgetProvider';
const providerSleep = 'com.tarun_siddhi.vital_up.SleepWidgetProvider';
const providerFoodLog = 'com.tarun_siddhi.vital_up.FoodLogWidgetProvider';
const providerMood = 'com.tarun_siddhi.vital_up.MoodWidgetProvider';
const providerStats = 'com.tarun_siddhi.vital_up.StatsProgressWidgetProvider';
const providerHydration = 'com.tarun_siddhi.vital_up.HydrationWidgetProvider';
const providerActivity = 'com.tarun_siddhi.vital_up.ActivityWidgetProvider';
const providerShortcuts = 'com.tarun_siddhi.vital_up.QuickShortcutsWidgetProvider';

const allWidgetProviders = [
  providerMultiFeature,
  providerSleep,
  providerFoodLog,
  providerMood,
  providerStats,
  providerHydration,
  providerActivity,
  providerShortcuts,
];

/// Background callback triggered from Home Screen Widget interactive buttons.
@pragma('vm:entry-point')
Future<void> homeWidgetCallback(Uri? uri) async {
  if (uri == null || uri.host != 'widget') return;
  try {
    final userId = await HomeWidget.getWidgetData<String>('user_id')
        .timeout(const Duration(seconds: 4), onTimeout: () => null);

    if (uri.path.startsWith('/add-water')) {
      int amount = HomeWidgetService.addMl;
      if (uri.path == '/add-water-100') {
        amount = 100;
      } else if (uri.path == '/add-water-500') {
        amount = 500;
      } else if (uri.path == '/add-water-1000') {
        amount = 1000;
      } else if (uri.queryParameters['amount'] != null) {
        amount = int.tryParse(uri.queryParameters['amount']!) ?? 250;
      }

      if (userId != null && userId.isNotEmpty) {
        final total = await addWaterInBackground(userId, amount)
            .timeout(const Duration(seconds: 5), onTimeout: () => 0);
        if (total > 0) {
          await HomeWidget.saveWidgetData<int>('water_ml', total);
        }
      } else {
        final current = await HomeWidget.getWidgetData<int>('water_ml') ?? 0;
        await HomeWidget.saveWidgetData<int>('water_ml', current + amount);
      }
    } else if (uri.path == '/select-mood' || uri.path == '/log-mood') {
      final level = int.tryParse(uri.queryParameters['level'] ?? '2') ?? 2;
      await HomeWidget.saveWidgetData<int>('mood_selected_level', level);
      await HomeWidget.saveWidgetData<String>(
        'last_updated',
        DateTime.now().toIso8601String(),
      );
    } else if (uri.path == '/submit-mood' || uri.path == '/checkin-mood') {
      final level = (await HomeWidget.getWidgetData<int>('mood_selected_level') ?? 2).clamp(1, 5);
      final tags = await HomeWidget.getWidgetData<String>('mood_selected_tags') ?? '';
      const moodLabels = ['Very calm', 'Calm', 'Okay', 'Stressed', 'Very stressed'];
      const moodSubtitles = [
        'Nice — keep that calm going.',
        'Nice — keep that calm going.',
        'Steady day. A short walk can lift it.',
        'Tough one. Try a 2-minute breathing break.',
        'Tough one. Try a 2-minute breathing break.',
      ];
      final label = moodLabels[(level - 1).clamp(0, 4)];
      final defaultSubtitle = moodSubtitles[(level - 1).clamp(0, 4)];
      final subtitle = tags.isNotEmpty ? tags.split(',').join(' · ') : defaultSubtitle;

      // Save directly into local database (SharedPreferences/VitaLocalDataSource)
      if (userId != null && userId.isNotEmpty) {
        final parsedTags = tags.isNotEmpty
            ? tags
                .split(',')
                .map((t) => StressTag.fromName(t.trim().toLowerCase()))
                .whereType<StressTag>()
                .toList()
            : <StressTag>[];
        final streak = await saveMoodInBackground(userId, level, parsedTags)
            .timeout(const Duration(seconds: 5), onTimeout: () => 0);
        if (streak > 0) {
          await HomeWidget.saveWidgetData<int>('streak', streak);
        }
      }

      await HomeWidget.saveWidgetData<bool>('mood_logged_today', true);
      await HomeWidget.saveWidgetData<int>('mood_level', level);
      await HomeWidget.saveWidgetData<String>('mood_state', label);
      await HomeWidget.saveWidgetData<String>('mood_subtitle', subtitle);
      await HomeWidget.saveWidgetData<String>(
        'last_updated',
        DateTime.now().toIso8601String(),
      );
    } else if (uri.path == '/reset-mood' || uri.path == '/edit-mood') {
      // Remove today's check-in from database
      if (userId != null && userId.isNotEmpty) {
        final streak = await resetMoodInBackground(userId)
            .timeout(const Duration(seconds: 5), onTimeout: () => 0);
        if (streak >= 0) {
          await HomeWidget.saveWidgetData<int>('streak', streak);
        }
      }

      await HomeWidget.saveWidgetData<bool>('mood_logged_today', false);
      await HomeWidget.saveWidgetData<String>('mood_selected_tags', '');
      await HomeWidget.saveWidgetData<String>(
        'last_updated',
        DateTime.now().toIso8601String(),
      );
    } else if (uri.path == '/refresh') {
      if (userId != null && userId.isNotEmpty) {
        // Read latest water from database
        final total = await getTodayWaterInBackground(userId)
            .timeout(const Duration(seconds: 5), onTimeout: () => 0);
        if (total > 0) {
          await HomeWidget.saveWidgetData<int>('water_ml', total);
        }

        // Read latest mood from database
        final todayCheckIn = await getTodayMoodInBackground(userId)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (todayCheckIn != null) {
          final message = switch (todayCheckIn.level) {
            1 || 2 => 'Nice — keep that calm going.',
            3 => 'Steady day. A short walk can lift it.',
            _ => 'Tough one. Try a 2-minute breathing break.',
          };
          final subtitle = todayCheckIn.tags.isNotEmpty
              ? todayCheckIn.tags.map((t) => t.label).join(' · ')
              : message;
          await HomeWidget.saveWidgetData<bool>('mood_logged_today', true);
          await HomeWidget.saveWidgetData<int>('mood_level', todayCheckIn.level);
          await HomeWidget.saveWidgetData<String>('mood_state', todayCheckIn.label);
          await HomeWidget.saveWidgetData<String>('mood_subtitle', subtitle);
        } else {
          await HomeWidget.saveWidgetData<bool>('mood_logged_today', false);
        }
      }
      await HomeWidget.saveWidgetData<String>(
        'last_updated',
        DateTime.now().toIso8601String(),
      );
    }
  } catch (e) {
    debugPrint('Background widget action error: $e');
  } finally {
    // ALWAYS trigger widget updates so native loading spinners are dismissed cleanly
    for (final p in allWidgetProviders) {
      await HomeWidget.updateWidget(qualifiedAndroidName: p);
    }
  }
}

/// Keeps all 8 Android home screen widgets synchronized with user data.
class HomeWidgetService {
  final SupabaseClient _client;
  final WaterIntakeService _water;
  final GamificationRepository _game;
  final ActivityGoalsRepository? _activityGoals;
  final GetMealLogHistory? _mealLogs;
  final VitaRepository? _vita;

  HomeWidgetService(
    this._client,
    this._water,
    this._game, {
    ActivityGoalsRepository? activityGoals,
    GetMealLogHistory? mealLogs,
    VitaRepository? vita,
  })  : _activityGoals = activityGoals,
        _mealLogs = mealLogs,
        _vita = vita;

  static const addMl = 250;

  static String? _pendingRoute;

  /// Consumes and clears any pending launch route received during cold start.
  static String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  AppLifecycleListener? _lifecycle;
  StreamSubscription<HabitLogged>? _habits;
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<Uri?>? _widgetClicks;

  bool get _supported => Platform.isAndroid;

  /// Refreshes now, after habits are logged, on auth change, when app backgrounds,
  /// and listens continuously for widget click deep links.
  void start(Stream<HabitLogged> habits) {
    if (!_supported || _lifecycle != null) return;
    HomeWidget.registerInteractivityCallback(homeWidgetCallback);
    _lifecycle = AppLifecycleListener(onHide: refresh);
    _habits = habits.listen((_) => refresh());
    _auth = _client.auth.onAuthStateChange.listen((_) => refresh());

    // Check initial cold-start launch URI from home widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      final route = routeOf(uri);
      if (route != null) {
        _pendingRoute = route;
        navigateWithBackstack(null, route);
      }
    });

    // Listen continuously for widget clicks while app is open or in background
    _widgetClicks = HomeWidget.widgetClicked.listen((uri) {
      final route = routeOf(uri);
      if (route != null) {
        navigateWithBackstack(null, route);
      }
    });

    refresh();
  }

  void dispose() {
    _lifecycle?.dispose();
    _habits?.cancel();
    _auth?.cancel();
    _widgetClicks?.cancel();
  }

  /// Refreshes all metrics for all home widgets with global timeout and guaranteed UI release.
  Future<void> refresh() async {
    if (!_supported) return;
    try {
      final userId = _client.auth.currentUser?.id;
      final isSignedIn = userId != null && userId.isNotEmpty;
      await HomeWidget.saveWidgetData<bool>('signed_in', isSignedIn);
      await HomeWidget.saveWidgetData<String>('user_id', userId ?? '');

      if (isSignedIn) {
        final futures = <Future<void>>[
          // 1. Water logs & goal
          _water
              .getTodayLogs(userId)
              .then((todayLogs) async {
                final waterTotal = todayLogs.fold<int>(0, (sum, l) => sum + l.amountMl);
                final waterGoal = _water.getDailyGoal();
                await HomeWidget.saveWidgetData<int>('water_ml', waterTotal);
                await HomeWidget.saveWidgetData<int>('water_goal_ml', waterGoal);
              })
              .catchError((_) {}),

          // 2. Gamification: streak & daily points
          _game
              .getStats()
              .then((stats) async {
                await HomeWidget.saveWidgetData<int>('streak', stats.streak);
                await HomeWidget.saveWidgetData<String>(
                  'stats_rank_tag',
                  'Level ${stats.streak > 0 ? (stats.streak ~/ 2 + 1) : 1} • Rank #4',
                );
              })
              .catchError((_) {}),

          _game
              .getPointsForDay(DateTime.now())
              .then((points) async {
                final ptsToday = points.values.fold<int>(0, (sum, p) => sum + p);
                await HomeWidget.saveWidgetData<int>('points_today', ptsToday);
              })
              .catchError((_) {}),
        ];

        // 3. Activity / Steps progress
        if (_activityGoals != null) {
          futures.add(
            _activityGoals!
                .getProgress(TrendRange.week)
                .then((snapshot) async {
                  final stepProgress = snapshot.goals
                      .where((g) => g.goal.metric == GoalMetric.steps)
                      .firstOrNull;
                  if (stepProgress != null) {
                    await HomeWidget.saveWidgetData<int>(
                      'steps',
                      stepProgress.current.toInt(),
                    );
                    await HomeWidget.saveWidgetData<int>(
                      'steps_goal',
                      stepProgress.goal.target.toInt(),
                    );
                  }
                  final activeGoal = snapshot.goals
                      .where((g) => g.goal.metric == GoalMetric.activeMinutes)
                      .firstOrNull;
                  if (activeGoal != null) {
                    await HomeWidget.saveWidgetData<int>(
                      'active_minutes',
                      activeGoal.current.toInt(),
                    );
                  }
                  final calGoal = snapshot.goals
                      .where((g) => g.goal.metric == GoalMetric.calories)
                      .firstOrNull;
                  if (calGoal != null) {
                    await HomeWidget.saveWidgetData<int>(
                      'calories_burned',
                      calGoal.current.toInt(),
                    );
                  }
                  final completedCount = snapshot.goals.where((g) => g.achieved).length;
                  await HomeWidget.saveWidgetData<int>('goals_completed', completedCount);
                  await HomeWidget.saveWidgetData<int>('goals_total', snapshot.goals.length);
                })
                .catchError((_) {}),
          );
        }

        // 4. Meal / Calories & Macros progress
        if (_mealLogs != null) {
          futures.add(
            _mealLogs!(DateTime.now())
                .then((result) async {
                  result.fold((_) {}, (meals) async {
                    int totalCals = 0;
                    int totalP = 0;
                    int totalC = 0;
                    int totalF = 0;
                    for (final m in meals) {
                      totalCals += m.totalCalories.toInt();
                      for (final n in m.nutrition) {
                        totalP += n.proteinG.toInt();
                        totalC += n.carbsG.toInt();
                        totalF += n.fatG.toInt();
                      }
                    }
                    await HomeWidget.saveWidgetData<int>('calories_consumed', totalCals);
                    await HomeWidget.saveWidgetData<int>('calories_goal', 2000);
                    await HomeWidget.saveWidgetData<int>('protein_g', totalP > 0 ? totalP : 110);
                    await HomeWidget.saveWidgetData<int>('carbs_g', totalC > 0 ? totalC : 185);
                    await HomeWidget.saveWidgetData<int>('fat_g', totalF > 0 ? totalF : 52);
                  });
                })
                .catchError((_) {}),
          );
        }

        // 5. Mood / Stress check-in progress
        if (_vita != null) {
          futures.add(
            Future.microtask(() async {
              final checkIns = _vita!.getStressCheckIns();
              final now = DateTime.now();
              final todayCheckIn = checkIns.where((c) =>
                  c.date.year == now.year &&
                  c.date.month == now.month &&
                  c.date.day == now.day).firstOrNull;

              final currentStreak = stressStreak(checkIns, now: now);
              if (currentStreak > 0) {
                await HomeWidget.saveWidgetData<int>('streak', currentStreak);
              }

              if (todayCheckIn != null) {
                final message = switch (todayCheckIn.level) {
                  1 || 2 => 'Nice — keep that calm going.',
                  3 => 'Steady day. A short walk can lift it.',
                  _ => 'Tough one. Try a 2-minute breathing break.',
                };
                final subtitle = todayCheckIn.tags.isNotEmpty
                    ? todayCheckIn.tags.map((t) => t.label).join(' · ')
                    : message;

                await HomeWidget.saveWidgetData<bool>('mood_logged_today', true);
                await HomeWidget.saveWidgetData<int>('mood_level', todayCheckIn.level);
                await HomeWidget.saveWidgetData<String>('mood_state', todayCheckIn.label);
                await HomeWidget.saveWidgetData<String>('mood_subtitle', subtitle);
              } else {
                await HomeWidget.saveWidgetData<bool>('mood_logged_today', false);
              }
            }).catchError((_) {}),
          );
        }

        // Global timeout of 6 seconds for all concurrent API updates
        await Future.wait(futures).timeout(const Duration(seconds: 6), onTimeout: () => []);
      }
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    } finally {
      await HomeWidget.saveWidgetData<String>(
        'last_updated',
        DateTime.now().toIso8601String(),
      );

      for (final p in allWidgetProviders) {
        await HomeWidget.updateWidget(qualifiedAndroidName: p);
      }
    }
  }

  /// Normalizes deep link route names or feature aliases to registered app routes.
  /// If the target represents multiple features or is not specified, defaults to 'dashboard'.
  static String normalizeFeatureRoute(String? raw) {
    if (raw == null || raw.isEmpty) return 'dashboard';
    final cleaned = raw.toLowerCase().trim().replaceAll('/', '');
    switch (cleaned) {
      // Multi-feature or dashboard
      case 'dashboard':
      case 'main':
      case 'home':
      case 'multi':
      case 'multiple':
      case 'multi-feature':
      case 'overview':
      case 'summary':
        return 'dashboard';

      // Hydration / Water
      case 'water':
      case 'water-trends':
      case 'hydration':
      case 'water-intake':
      case 'water-log':
        return 'water-trends';

      // Activity / Steps / Workout
      case 'activity':
      case 'activity-tracking':
      case 'steps':
      case 'workout':
      case 'run':
      case 'fitness':
        return 'activity-tracking';
      case 'activity-goals':
        return 'activity-goals';
      case 'activity-history':
      case 'workout-history':
        return 'activity-history';

      // Food / Nutrition / Meals
      case 'scan':
      case 'food-scan':
      case 'camera-scan':
        return 'food-scan';
      case 'food':
      case 'nutrition':
      case 'meals':
      case 'meal':
      case 'diet':
      case 'calorie':
      case 'calories':
      case 'diet-progress':
      case 'macros':
        return 'diet-progress';
      case 'meal-log-history':
      case 'meal-history':
      case 'food-history':
        return 'meal-log-history';

      // Sleep & Recovery
      case 'sleep':
      case 'sleep-trends':
      case 'rest':
      case 'recovery':
        return 'sleep-trends';

      // Mood / Mindfulness / Stress
      case 'mood':
      case 'mindfulness':
      case 'stress':
      case 'stress-trends':
      case 'check-in':
      case 'mood-log':
        return 'stress-trends';
      case 'vita-stress':
        return 'vita-stress';

      // Vita AI
      case 'vita':
      case 'vita-chat':
      case 'ai':
      case 'coach':
      case 'vita-ai':
        return 'vita-chat';
      case 'vita-analysis':
      case 'analysis':
        return 'vita-analysis';
      case 'vita-diet-plan':
        return 'vita-diet-plan';

      // Gamification / Points / Badges / Goals
      case 'leaderboard':
      case 'rank':
      case 'ranking':
      case 'xp':
      case 'stats':
      case 'gamification':
      case 'score':
      case 'points-history':
      case 'points':
      case 'streak':
        return 'points-history';
      case 'badges':
      case 'achievements':
        return 'badges';
      case 'challenges':
      case 'quests':
        return 'challenges';
      case 'my-goals':
      case 'goals':
        return 'my-goals';

      // Weight & Screen Time
      case 'weight':
      case 'weight-trends':
        return 'weight-trends';
      case 'screen-time':
      case 'screen-time-trends':
        return 'screen-time-trends';

      // Health Report
      case 'health-report':
      case 'report':
        return 'health-report';

      // Settings & Reminders & Widgets
      case 'settings':
        return 'settings';
      case 'reminders':
        return 'reminders';
      case 'home-widgets':
      case 'widgets':
        return 'home-widgets';
      case 'custom-widget-builder':
      case 'custom-widget':
        return 'custom-widget-builder';

      // Auth
      case 'login':
      case 'quick-login':
      case 'signin':
        return 'login';

      default:
        return raw;
    }
  }

  /// Parses in-app route from deep link URI.
  /// Handles `vitalup://widget/open?route=...`, `vitalup://<route>`, `vitalup://widget/quick-login`.
  /// If multiple features or unspecified, returns 'dashboard'.
  static String? routeOf(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme == 'vitalup') {
      if (uri.host == 'widget') {
        if (uri.path == '/open') {
          final target = uri.queryParameters['route'] ?? uri.queryParameters['feature'];
          return normalizeFeatureRoute(target);
        } else if (uri.path == '/quick-login') {
          return 'login';
        } else if (uri.path.isNotEmpty && uri.path != '/') {
          return normalizeFeatureRoute(uri.path.replaceAll('/', ''));
        }
        return 'dashboard';
      } else if (uri.host.isNotEmpty) {
        // e.g. vitalup://food-scan or vitalup://water-trends or vitalup://dashboard
        return normalizeFeatureRoute(uri.host);
      }
    }
    return null;
  }

  /// Navigates to the given route with proper backstack management.
  /// Ensures individual features push onto the stack while multiple features / home open Dashboard.
  static void navigateWithBackstack(BuildContext? context, String route) {
    final isSignedIn = Supabase.instance.client.auth.currentUser != null;

    if (route == 'login' || route == 'quick-login') {
      if (!isSignedIn) {
        if (context != null && context.mounted) {
          context.pushNamed('login');
        } else {
          AppRouter.router.pushNamed('login');
        }
      } else {
        if (context != null && context.mounted) {
          context.goNamed('dashboard');
        } else {
          AppRouter.router.goNamed('dashboard');
        }
      }
      return;
    }

    if (route == 'dashboard') {
      if (context != null && context.mounted) {
        context.goNamed('dashboard');
      } else {
        AppRouter.router.goNamed('dashboard');
      }
      return;
    }

    // List of known routes that should be pushed on top of Dashboard
    final validRoutes = <String>{
      ...notificationLinkableRoutes,
      'dashboard',
      'login',
      'water-trends',
      'sleep-trends',
      'stress-trends',
      'weight-trends',
      'screen-time-trends',
      'activity-tracking',
      'activity-goals',
      'activity-history',
      'food-scan',
      'meal-log-history',
      'diet-progress',
      'my-goals',
      'points-history',
      'badges',
      'challenges',
      'friends',
      'vita-chat',
      'vita-analysis',
      'vita-diet-plan',
      'vita-stress',
      'health-report',
      'weekly-summary',
      'reminders',
      'home-widgets',
      'custom-widget-builder',
      'settings',
      'help-support',
      'about',
    };

    if (validRoutes.contains(route)) {
      try {
        if (context != null && context.mounted) {
          context.goNamed('dashboard');
          context.pushNamed(route);
        } else {
          AppRouter.router.goNamed('dashboard');
          AppRouter.router.pushNamed(route);
        }
      } catch (e) {
        debugPrint('Navigation error for route $route: $e');
        if (context != null && context.mounted) {
          context.goNamed('dashboard');
        } else {
          AppRouter.router.goNamed('dashboard');
        }
      }
    } else {
      if (context != null && context.mounted) {
        context.goNamed('dashboard');
      } else {
        AppRouter.router.goNamed('dashboard');
      }
    }
  }
}
