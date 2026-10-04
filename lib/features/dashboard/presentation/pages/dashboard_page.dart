import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/widgets/tracker/quick_log_hub.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import 'package:vital_up/features/weight/presentation/weight_entry_sheet.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/health_sync/health_import_service.dart';
import 'package:vital_up/features/weekly_summary/weekly_summary_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:vital_up/core/events/habit_events.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';
import 'package:vital_up/features/weight/presentation/weight_trends_page.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_bottom_nav.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/features/profile/presentation/pages/profile_page.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/community/presentation/pages/community_hub_page.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_state.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_state.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/gamification/presentation/widgets/reward_celebration_dialog.dart';
import 'package:vital_up/features/gamification/presentation/widgets/score_streak_card.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/activity_goals_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/stress_checkin_card.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';
import 'package:vital_up/features/notifications/data/services/push_service.dart';
import 'package:vital_up/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/profile/presentation/widgets/top_bar_player_identity.dart';
import 'package:vital_up/features/profile/presentation/widgets/username_input.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_home_page.dart';
import '../widgets/screen_time_card.dart';
import '../widgets/sleep_card.dart';
import '../widgets/smart_overview_card.dart';
import '../widgets/water_intake_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DietPlanCubit _dietPlanCubit;
  late final ProfileCubit _profileCubit;
  StreamSubscription<PushOpen>? _pushOpens;
  StreamSubscription<Uri?>? _widgetClicks;
  int _selectedIndex = 0;
  final List<int> _navigationQueue = [0];

  @override
  void initState() {
    super.initState();
    _dietPlanCubit = sl<DietPlanCubit>()..loadActiveMealPlan();
    // Syncs the profile (incl. calorie goal) into the local cache that the
    // nutrition card reads.
    _profileCubit = sl<ProfileCubit>()..loadProfile();

    sl<HealthImportService>().start();
    // Both only reach the server when something changed (time zone, push
    // token or account) since they last did.
    sl<WeeklySummaryService>().reportTimezone();

    final push = sl<PushService>();
    push.requestPermissionAndRegister();
    _pushOpens = push.opens.listen(_openPush);

    sl<HomeWidgetService>().start(sl<HabitEvents>().stream);
    _widgetClicks = HomeWidget.widgetClicked.listen(_openWidgetRoute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final launch = push.takePendingOpen();
      if (launch != null) _openPush(launch);
      final pendingWidgetRoute = HomeWidgetService.consumePendingRoute();
      if (pendingWidgetRoute != null) {
        HomeWidgetService.navigateWithBackstack(context, pendingWidgetRoute);
      } else {
        HomeWidget.initiallyLaunchedFromHomeWidget().then(_openWidgetRoute);
      }
      _askForUsernameIfNeeded();
    });
  }

  /// Google sign-ups who got past onboarding without choosing a username
  /// (signed up before it was asked, or it couldn't load then).
  Future<void> _askForUsernameIfNeeded() async {
    final service = sl<UsernameService>();
    try {
      final status = await service.fetchStatus();
      if (!mounted || status == null || status.confirmed) return;
      await showUsernamePrompt(
        context,
        service: service,
        suggestion: status.username,
      );
      // Profile shows the username; refresh it now it's changed.
      if (mounted) _profileCubit.loadProfile();
    } catch (e) {
      debugPrint('Username check failed: $e');
    }
  }

  /// A tapped push opens the screen its notification links to.
  /// The home screen widget was tapped (routes to water, scan, activity, vita, or login).
  void _openWidgetRoute(Uri? uri) {
    final route = HomeWidgetService.routeOf(uri);
    if (!mounted || route == null) return;
    HomeWidgetService.navigateWithBackstack(context, route);
  }

  void _openPush(PushOpen open) {
    if (!mounted) return;
    final route = notificationRoute(open.type, open.route);
    if (route != null) context.pushNamed(route);
  }

  @override
  void dispose() {
    _pushOpens?.cancel();
    _widgetClicks?.cancel();
    _dietPlanCubit.close();
    _profileCubit.close();
    super.dispose();
  }

  static const _items = [
    AppBottomNavItem('Home', 'assets/icons/home.svg'),
    AppBottomNavItem('Scan', 'assets/icons/scanner.svg'),
    AppBottomNavItem('Vita', 'assets/icons/vita.svg'),
    AppBottomNavItem('Arena', GamificationIcons.community),
    AppBottomNavItem('Profile', 'assets/icons/profile.svg'),
  ];

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      if (index == 0) {
        _navigationQueue
          ..clear()
          ..add(0);
      } else {
        _navigationQueue.remove(index);
        _navigationQueue.add(index);
      }
      _selectedIndex = index;
    });
  }

  void _handlePop() {
    if (_navigationQueue.length > 1) {
      setState(() {
        _navigationQueue.removeLast();
        _selectedIndex = _navigationQueue.last;
      });
    } else if (_selectedIndex != 0) {
      setState(() {
        _navigationQueue
          ..clear()
          ..add(0);
        _selectedIndex = 0;
      });
    }
  }

  bool get _canPop => _selectedIndex == 0 && _navigationQueue.length <= 1;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.goNamed('onboarding');
        }
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileCubit>.value(value: _profileCubit),
          BlocProvider<DietPlanCubit>.value(value: _dietPlanCubit),
          BlocProvider<WaterIntakeCubit>(
            create: (context) =>
                sl<WaterIntakeCubit>()..loadData(_userId(context)),
          ),
          BlocProvider<TrendCubit<WaterLogCache>>(
            create: (context) {
              final userId = _userId(context);
              return TrendCubit<WaterLogCache>(
                (range) => sl<TrendsService>().water(userId, range),
              )..load();
            },
          ),
          BlocProvider<ActivityGoalsCubit>(
            create: (_) => sl<ActivityGoalsCubit>()..load(),
          ),
          BlocProvider<GamificationCubit>(
            create: (_) => sl<GamificationCubit>()
              ..load()
              ..sync(),
          ),
          BlocProvider<NotificationsCubit>(
            create: (_) => sl<NotificationsCubit>()
              ..load()
              ..watch(),
          ),
          BlocProvider<StressCheckInCubit>(
            create: (_) => sl<StressCheckInCubit>()..load(),
          ),
          BlocProvider<TrendCubit<MealLogEntry>>(
            create: (_) =>
                TrendCubit<MealLogEntry>(sl<TrendsService>().calories)..load(),
          ),
          BlocProvider<TrendCubit<SleepSessionInfo>>(
            create: (_) =>
                TrendCubit<SleepSessionInfo>(sl<TrendsService>().sleep)..load(),
          ),
          BlocProvider<TrendCubit<WeightLogCache>>(
            create: (_) =>
                TrendCubit<WeightLogCache>(sl<WeightService>().trend)..load(),
          ),
          BlocProvider<ScreenTimeCubit>(
            create: (context) => sl<ScreenTimeCubit>()..loadStats(),
          ),
          BlocProvider<SleepCubit>(
            create: (context) => sl<SleepCubit>()..loadSleepData(),
          ),
        ],
        child: BlocListener<GamificationCubit, GamificationState>(
          listenWhen: (prev, next) => next.awardId != prev.awardId,
          listener: (context, state) {
            final award = state.award;
            if (award != null) showRewardCelebration(context, award);
          },
          child: PopScope(
            canPop: _canPop,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _handlePop();
            },
            child: Scaffold(
              backgroundColor: context.theme.scaffoldBackgroundColor,
              extendBody: true,
              body: _buildSelectedTab(context),
              bottomNavigationBar: _selectedIndex == 1
                  ? null
                  : AppBottomNav(
                      items: _items,
                      selectedIndex: _selectedIndex,
                      onItemSelected: _selectTab,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  static String _userId(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    return authState is AuthAuthenticated ? authState.user.id : 'unknown';
  }

  Widget _buildSelectedTab(BuildContext context) {
    return switch (_selectedIndex) {
      0 => BlocProvider<MealLogBloc>(
        create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
        child: BlocListener<ProfileCubit, ProfileState>(
          bloc: _profileCubit,
          listenWhen: (_, state) => state is ProfileLoaded,
          // Re-read so the calorie goal appears once the profile syncs.
          listener: (context, _) =>
              context.read<MealLogBloc>().add(const LoadTodaysMeals()),
          child: _HomeTab(onScanMeal: () => _selectTab(1)),
        ),
      ),
      1 => FoodScannerPage(onBack: _handlePop),
      2 => VitaHomePage(onBack: _handlePop),
      3 => const CommunityHubPage(),
      _ => BlocProvider.value(
        value: _profileCubit,
        child: const ProfilePage(),
      ),
    };
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback? onScanMeal;
  const _HomeTab({this.onScanMeal});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // Health Connect data (steps, synced sleep) changes outside the app.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (!mounted) return;
      context.read<WaterIntakeCubit>().reload();
      context.read<TrendCubit<SleepSessionInfo>>().load();
      context.read<ActivityGoalsCubit>().load();
      context.read<StressCheckInCubit>().reload();
      context.read<MealLogBloc>().add(const LoadTodaysMeals());
      context.read<GamificationCubit>().sync();
      // The realtime feed can drop while backgrounded; cache-first, so this
      // only refetches when the inbox is a few minutes old.
      context.read<NotificationsCubit>().load();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    context.read<WaterIntakeCubit>().reload();
    context.read<SleepCubit>().loadSleepData();
    context.read<TrendCubit<SleepSessionInfo>>().load();
    context.read<ScreenTimeCubit>().loadStats();
    context.read<TrendCubit<WeightLogCache>>().load();
    context.read<ActivityGoalsCubit>().load();
    context.read<StressCheckInCubit>().reload();
    context.read<MealLogBloc>().add(const LoadTodaysMeals());
    context.read<DietPlanCubit>().loadActiveMealPlan();
    context.read<GamificationCubit>().sync();
    context.read<NotificationsCubit>().load();

    await sl<HomeWidgetService>().refresh();

    if (mounted) {
      showSuccessSnackBar(context, 'Widget & health data refreshed');
    }
  }

  /// The header "+": pick a metric, then open its log sheet here so the
  /// home cards refresh as soon as it's saved.
  Future<void> _openQuickLog() async {
    final choice = await showQuickLogHub(context);
    if (!mounted || choice == null) return;
    switch (choice) {
      case QuickLogGoals():
        await context.pushNamed('my-goals');
        if (mounted) _refreshAllData();
      case QuickLogMetric(:final metric):
        await _logMetric(metric);
    }
  }

  Future<void> _logMetric(TrackerMetric metric) async {
    switch (metric) {
      case TrackerMetric.nutrition:
        widget.onScanMeal?.call();
      case TrackerMetric.activity:
        await _push('activity-tracking');
        if (mounted) context.read<ActivityGoalsCubit>().load();
      case TrackerMetric.mood:
        final cubit = context.read<StressCheckInCubit>();
        if (await showMoodLogSheet(context, initial: cubit.state.today)) {
          cubit.load();
        }
      case TrackerMetric.water:
        final cubit = context.read<WaterIntakeCubit>();
        await showWaterLogSheet(context, onAdd: cubit.addWater);
      case TrackerMetric.sleep:
        final sleep = context.read<SleepCubit>();
        final trend = context.read<TrendCubit<SleepSessionInfo>>();
        if (await showSleepLogSheet(context)) {
          sleep.loadSleepData();
          trend.load();
        }
      case TrackerMetric.weight:
        final trend = context.read<TrendCubit<WeightLogCache>>();
        if (await showWeightEntrySheet(context)) trend.load();
      case TrackerMetric.screenTime:
        break;
    }
  }

  Future<void> _push(String route, {Object? extra}) async {
    final meals = context.read<MealLogBloc>();
    final calories = context.read<TrendCubit<MealLogEntry>>();
    final plan = context.read<DietPlanCubit>();
    await context.pushNamed(route, extra: extra);
    meals.add(const LoadTodaysMeals());
    calories.load();
    plan.loadActiveMealPlan();
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space12, left: AppDimens.space4, top: AppDimens.space8),
      child: Text(
        title.toUpperCase(),
        style: context.text.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: context.vColors.grayText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onScanMeal = widget.onScanMeal;
    // With Scaffold.extendBody the floating nav bar height is reported as
    // bottom padding, so content always clears it.
    final bottomInset = context.safePadding.bottom + AppDimens.sectionGap;

    // Any logged data can earn points; the cubit debounces bursts.
    void sync(BuildContext context, _) =>
        context.read<GamificationCubit>().sync();

    return MultiBlocListener(
      listeners: [
        BlocListener<WaterIntakeCubit, WaterIntakeState>(listener: sync),
        BlocListener<StressCheckInCubit, StressCheckInState>(listener: sync),
        BlocListener<SleepCubit, SleepState>(listener: sync),
        BlocListener<
          TrendCubit<SleepSessionInfo>,
          TrendState<SleepSessionInfo>
        >(listener: sync),
        BlocListener<ActivityGoalsCubit, ActivityGoalsState>(
          listenWhen: (prev, next) => next.snapshot != prev.snapshot,
          listener: sync,
        ),
        BlocListener<MealLogBloc, MealLogState>(
          listenWhen: (_, state) => state is MealLogLoaded,
          listener: sync,
        ),
        BlocListener<DietPlanCubit, DietPlanState>(listener: sync),
      ],
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          Column(
            children: [
              AppPageHeader(
                showBack: false,
                titleWidget: const TopBarPlayerIdentity(),
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppHeaderAction(
                      tooltip: 'Activity Calendar',
                      icon: const Icon(Icons.calendar_month_rounded),
                      onTap: () => context.pushNamed('activity-calendar'),
                    ),
                    const SizedBox(width: AppDimens.space8),
                    AppHeaderAction(
                      tooltip: 'Log something',
                      icon: const Icon(Icons.add_rounded),
                      onTap: _openQuickLog,
                    ),
                    const SizedBox(width: AppDimens.space8),
                    BlocBuilder<NotificationsCubit, NotificationsState>(
                      buildWhen: (prev, next) =>
                          prev.unreadCount != next.unreadCount,
                      builder: (context, state) => NotificationBellButton(
                        unread: state.unreadCount,
                        onTap: () => context.pushNamed(
                          'notifications',
                          extra: context.read<NotificationsCubit>(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: AppDimens.sectionGap,
                      bottom: bottomInset,
                    ),
                    child: ResponsiveCenter(
                      child: Padding(
                        padding: context.pagePadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionTitle(context, 'Overview'),
                            const SmartOverviewCard(),
                            const SizedBox(height: AppDimens.cardGap),
                            const ActivityGoalsCard(),
                            const SizedBox(height: AppDimens.sectionGap),

                            _buildSectionTitle(context, 'Body & Nutrition'),
                            BlocListener<MealLogBloc, MealLogState>(
                              // A newly logged meal moves today's calories bar.
                              listenWhen: (_, state) => state is MealLogLoaded,
                              listener: (context, _) => context
                                  .read<TrendCubit<MealLogEntry>>()
                                  .load(),
                              child: BlocBuilder<DietPlanCubit, DietPlanState>(
                                builder: (context, state) =>
                                    NutritionSummaryCard(
                                      plan: state is DietPlanLoaded
                                          ? state.mealPlan
                                          : null,
                                      onViewAll: () =>
                                          _push('meal-log-history'),
                                      onOpenProgress: () =>
                                          _push(TrackerMetric.nutrition.route),
                                      onScanMeal: onScanMeal,
                                      onCreatePlan: () =>
                                          _push('diet-plan-prefs'),
                                    ),
                              ),
                            ),
                            const SizedBox(height: AppDimens.cardGap),
                            SizedBox(
                              height: 240,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(child: WaterIntakeCard()),
                                  const SizedBox(width: AppDimens.cardGap),
                                  const Expanded(child: WeightCard()),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimens.sectionGap),

                            _buildSectionTitle(context, 'Mind & Rest'),
                            const StressCheckInCard(),
                            const SizedBox(height: AppDimens.cardGap),
                            SizedBox(
                              height: 240,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(child: SleepCard()),
                                  const SizedBox(width: AppDimens.cardGap),
                                  const Expanded(child: ScreenTimeCard()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

