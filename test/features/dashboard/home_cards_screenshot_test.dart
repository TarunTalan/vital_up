// Renders the Home tab's cards with fake data at several screen sizes and
// text scales, checks the layout is clean and (with HOME_SHOTS=1) writes a
// PNG per case to build/home_shots/ for a visual review:
//
//   HOME_SHOTS=1 flutter test test/features/dashboard/home_cards_screenshot_test.dart
//
// Without HOME_SHOTS only the layout checks run.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/activity_goals_card.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/app_usage_info.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_state.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_state.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_state.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/mood_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/screen_time_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/sleep_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/today_summary_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/water_intake_card.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import 'package:vital_up/features/weight/presentation/weight_trends_page.dart';

import '../../helpers/pump_app.dart';

/// Flip to true to turn the overflow / truncation reports into failures.
const _strict = true;

/// PNGs are written only when this is set (`HOME_SHOTS=1`).
final _writeShots = Platform.environment['HOME_SHOTS'] == '1';

/// Tall enough for the whole feed at the largest text size.
const _canvasHeight = 3200.0;

/// Screenshot resolution (dp to pixels).
const _shotPixelRatio = 2.0;

final _shotKey = GlobalKey();

// ---------------------------------------------------------------------------
// The feed. Mirrors `_HomeTabState.build` in dashboard_page.dart; edit here
// when the Home tab changes.
// ---------------------------------------------------------------------------

/// The Home tab's header and column (`_HomeTabState.build` in
/// dashboard_page.dart).
Widget homeFeed() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    AppPageHeader(
      showBack: false,
      titleWidget: const HomeGreeting(),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppHeaderAction(
            tooltip: 'Log something',
            icon: const Icon(Icons.add_rounded),
            onTap: () {},
          ),
          const SizedBox(width: AppDimens.space8),
          NotificationBellButton(unread: 3, onTap: () {}),
        ],
      ),
    ),
    const SizedBox(height: AppDimens.sectionGap),
    AppSectionHeader(
      'Today',
      note: 'Tue, 20 Oct',
      actionLabel: 'History',
      onAction: () {},
    ),
    TodaySummaryCard(onOpen: (_) {}),
    DashboardInsightCard(onLog: (_) {}),
    const SizedBox(height: AppDimens.sectionGap),

    const AppSectionHeader('Nutrition & activity'),
    BlocBuilder<DietPlanCubit, DietPlanState>(
      builder: (context, state) => NutritionSummaryCard(
        plan: state is DietPlanLoaded ? state.mealPlan : null,
        onOpenProgress: () {},
        onScanMeal: () {},
        onCreatePlan: () {},
        onOpenDietPlan: () {},
      ),
    ),
    const SizedBox(height: AppDimens.cardGap),
    const ActivityGoalsCard(),
    const SizedBox(height: AppDimens.sectionGap),

    const AppSectionHeader('Body & wellbeing'),
    const TrackerTilePair(left: WaterIntakeCard(), right: WeightCard()),
    const SizedBox(height: AppDimens.cardGap),
    const TrackerTilePair(left: SleepCard(), right: MoodCard()),
    const SizedBox(height: AppDimens.cardGap),
    const ScreenTimeSummaryRow(),
  ],
);

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeWater extends Cubit<WaterIntakeState> implements WaterIntakeCubit {
  _FakeWater(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSleep extends Cubit<SleepState> implements SleepCubit {
  _FakeSleep(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStress extends Cubit<StressCheckInState>
    implements StressCheckInCubit {
  _FakeStress(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoals extends Cubit<ActivityGoalsState>
    implements ActivityGoalsCubit {
  _FakeGoals(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMeals extends Bloc<MealLogEvent, MealLogState>
    implements MealLogBloc {
  _FakeMeals(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDietPlan extends Cubit<DietPlanState> implements DietPlanCubit {
  _FakeDietPlan(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScreenTime extends Cubit<ScreenTimeState>
    implements ScreenTimeCubit {
  _FakeScreenTime(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A trend that is already loaded; reloads keep the same data.
class _FakeProfile extends Cubit<ProfileState> implements ProfileCubit {
  _FakeProfile(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedTrend<L> extends TrendCubit<L> {
  _FixedTrend(TrendData<L>? data, {String? error})
    : super(
        (_) async => data ?? TrendData<L>(const TrendSeries([]), const []),
      ) {
    emit(
      TrendState<L>(
        loading: data == null && error == null,
        data: data,
        error: error,
      ),
    );
  }

  @override
  Future<void> load([TrendRange? range]) async {}
}

class _FakeSleepService implements SleepService {
  final int? goal;

  _FakeSleepService(this.goal);

  @override
  int? getGoalMinutes() => goal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScreenTimeService implements ScreenTimeService {
  @override
  int? getDailyLimitMinutes() => 4 * 60;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWeightService implements WeightService {
  final WeightUnit _unit;

  /// Every weigh-in, newest first (like the trend's logs).
  final List<WeightLogCache> _logs;

  _FakeWeightService(this._unit, this._logs);

  @override
  Future<WeightUnit> unit() async => _unit;

  @override
  Future<WeightLogCache?> latest() async => _logs.firstOrNull;

  @override
  Future<WeightLogCache?> first() async => _logs.lastOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// Everything the cards read, for one Home state.
class _Scenario {
  final String name;
  final WaterIntakeState water;
  final SleepState sleep;
  final StressCheckInState mood;
  final ActivityGoalsState goals;
  final MealLogState meals;
  final DietPlanState plan;
  final ScreenTimeState screenTime;
  final TrendData<WeightLogCache>? weight;
  final String? weightError;
  final WeightUnit weightUnit;
  final ProfileState profile;

  /// Null: the user removed their sleep goal.
  final int? sleepGoalMinutes;

  const _Scenario({
    required this.name,
    required this.water,
    required this.sleep,
    required this.mood,
    required this.goals,
    required this.meals,
    required this.plan,
    required this.screenTime,
    required this.weight,
    this.weightUnit = WeightUnit.kg,
    this.weightError,
    this.sleepGoalMinutes = 8 * 60,
    this.profile = const ProfileLoaded(
      ProfileEntity(
        id: 'u1',
        username: 'sam_lee',
        email: '',
        fullName: 'Sam Lee',
      ),
    ),
  });
}

WeightLogCache _weight(double kg, DateTime at) => WeightLogCache()
  ..userId = 'u1'
  ..weightKg = kg
  ..timestamp = at
  ..source = 'manual';

MealLogEntry _meal(String id, MealType type, DateTime at, double kcal) =>
    MealLogEntry(
      id: id,
      capturedAt: at,
      imagePath: '',
      items: const [],
      nutrition: const [],
      totalCalories: kcal,
      mealType: type,
      userConfirmed: true,
    );

/// A user in the middle of the afternoon with most things logged.
_Scenario _typical() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final wake = today.add(const Duration(hours: 6, minutes: 22));
  return _Scenario(
    name: 'typical',
    water: const WaterIntakeLoaded(
      currentIntakeMl: 1250,
      dailyGoalMl: 2500,
      todayLogs: [],
    ),
    sleep: SleepLoadedManual(
      SleepSessionInfo(
        bedTime: wake.subtract(const Duration(hours: 7, minutes: 12)),
        wakeTime: wake,
        duration: const Duration(hours: 7, minutes: 12),
        source: SleepDataSource.manual,
      ),
    ),
    mood: StressCheckInState(
      today: StressCheckIn(
        date: today.add(const Duration(hours: 13)),
        level: 2, // "Calm"
      ),
    ),
    goals: ActivityGoalsState(
      loading: false,
      snapshot: ActivityGoalsSnapshot(
        goals: [
          GoalProgress(
            goal: const ActivityGoal(
              metric: GoalMetric.steps,
              period: GoalPeriod.daily,
              target: 10000,
            ),
            current: 6240,
            series: TrendSeries([DailyPoint(today, 6240)], goal: 10000),
          ),
          GoalProgress(
            goal: const ActivityGoal(
              metric: GoalMetric.activeMinutes,
              period: GoalPeriod.daily,
              target: 30,
            ),
            current: 22,
            series: TrendSeries([DailyPoint(today, 22)], goal: 30),
          ),
          GoalProgress(
            goal: const ActivityGoal(
              metric: GoalMetric.workouts,
              period: GoalPeriod.weekly,
              target: 4,
            ),
            current: 2,
            series: TrendSeries([DailyPoint(today, 2)], goal: 4),
          ),
        ],
        sessions: const [],
        stepsFromHealth: true,
      ),
    ),
    meals: MealLogLoaded(
      entries: [
        _meal(
          'b',
          MealType.breakfast,
          today.add(const Duration(hours: 8)),
          420,
        ),
        _meal('l', MealType.lunch, today.add(const Duration(hours: 13)), 820),
      ],
      totalCalories: 1240,
      totalProteinG: 68,
      totalCarbsG: 142,
      totalFatG: 41,
      dailyCalorieGoal: 2000,
    ),
    plan: DietPlanInitial(),
    screenTime: const ScreenTimeLoaded(
      usageStats: [
        AppUsageInfo(
          appName: 'YouTube',
          packageName: 'com.google.android.youtube',
          usageDuration: Duration(hours: 1, minutes: 20),
        ),
      ],
      totalDuration: Duration(hours: 3, minutes: 5),
    ),
    weight: TrendData<WeightLogCache>(
      TrendSeries([DailyPoint(today, 72.4)], goal: 70),
      // Newest first, like WeightService.trend.
      [
        _weight(72.4, now),
        _weight(73.1, today.subtract(const Duration(days: 7))),
        _weight(74.0, today.subtract(const Duration(days: 30))),
      ],
    ),
  );
}

/// The longest figures a half-width tile shows: weight in lbs, a long
/// sleep still to review, the longest mood, water in litres with decimals.
_Scenario _long() {
  final base = _typical();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final wake = today.add(const Duration(hours: 7));
  return _Scenario(
    name: 'long',
    water: const WaterIntakeLoaded(
      currentIntakeMl: 2350,
      dailyGoalMl: 3500,
      todayLogs: [],
    ),
    sleep: SleepNeedsConfirmation(
      SleepSessionInfo(
        bedTime: wake.subtract(const Duration(hours: 10, minutes: 45)),
        wakeTime: wake,
        duration: const Duration(hours: 10, minutes: 45),
        source: SleepDataSource.phone,
      ),
    ),
    mood: StressCheckInState(
      today: StressCheckIn(
        date: today.add(const Duration(hours: 13)),
        level: 5, // "Very stressed"
      ),
    ),
    goals: base.goals,
    meals: base.meals,
    plan: base.plan,
    screenTime: base.screenTime,
    weight: TrendData<WeightLogCache>(
      TrendSeries([DailyPoint(today, 104.3)], goal: 95.2),
      [_weight(104.3, today.subtract(const Duration(days: 1)))],
    ),
    weightUnit: WeightUnit.lbs,
    profile: const ProfileLoaded(
      ProfileEntity(
        id: 'u1',
        username: 'alexandra_m',
        email: '',
        fullName: 'Alexandriana Montgomery-Wells',
      ),
    ),
  );
}

/// Water and sleep goals removed: figures with "today" / "last night",
/// no bars, rings or "Behind".
_Scenario _noGoals() {
  final base = _typical();
  return _Scenario(
    name: 'nogoals',
    water: const WaterIntakeLoaded(
      currentIntakeMl: 1250,
      dailyGoalMl: null,
      todayLogs: [],
    ),
    sleepGoalMinutes: null,
    sleep: base.sleep,
    mood: base.mood,
    goals: base.goals,
    meals: base.meals,
    plan: base.plan,
    screenTime: base.screenTime,
    weight: base.weight,
  );
}

/// A new user: nothing logged, no goals, no permissions.
_Scenario _empty() => _Scenario(
  name: 'empty',
  water: const WaterIntakeLoaded(
    currentIntakeMl: 0,
    dailyGoalMl: 2500,
    todayLogs: [],
  ),
  sleep: const SleepNeedsManualEntry(),
  mood: const StressCheckInState(),
  goals: const ActivityGoalsState(
    loading: false,
    snapshot: ActivityGoalsSnapshot(
      goals: [],
      sessions: [],
      stepsFromHealth: false,
    ),
  ),
  meals: const MealLogLoaded(
    entries: [],
    totalCalories: 0,
    totalProteinG: 0,
    totalCarbsG: 0,
    totalFatG: 0,
  ),
  plan: DietPlanInitial(),
  screenTime: ScreenTimePermissionDenied(),
  weight: const TrendData<WeightLogCache>(TrendSeries([]), []),
  profile: const ProfileLoaded(
    ProfileEntity(id: 'u1', username: 'sam_lee', email: ''),
  ),
);

/// Goals met, calories over, a diet plan, sleep in bed, screen time over
/// its limit, mood not checked in, weight last logged a week ago.
_Scenario _states() {
  final base = _typical();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return _Scenario(
    name: 'states',
    water: const WaterIntakeLoaded(
      currentIntakeMl: 2750,
      dailyGoalMl: 2500,
      todayLogs: [],
    ),
    sleep: SleepInBed(today.subtract(const Duration(hours: 1))),
    mood: const StressCheckInState(),
    goals: ActivityGoalsState(
      loading: false,
      snapshot: ActivityGoalsSnapshot(
        // The default goals with no steps counted but the workouts done:
        // the ring must not read 0%.
        goals: [
          GoalProgress(
            goal: const ActivityGoal(
              metric: GoalMetric.steps,
              period: GoalPeriod.daily,
              target: 8000,
            ),
            current: 0,
            series: TrendSeries([DailyPoint(today, 0)], goal: 8000),
          ),
          GoalProgress(
            goal: const ActivityGoal(
              metric: GoalMetric.workouts,
              period: GoalPeriod.weekly,
              target: 3,
            ),
            current: 3,
            series: TrendSeries([DailyPoint(today, 3)], goal: 3),
          ),
        ],
        sessions: const [],
        stepsFromHealth: false,
      ),
    ),
    meals: MealLogLoaded(
      entries: [
        _meal(
          'b',
          MealType.breakfast,
          today.add(const Duration(hours: 8)),
          640,
        ),
        _meal('l', MealType.lunch, today.add(const Duration(hours: 13)), 980),
        _meal('d', MealType.dinner, today.add(const Duration(hours: 20)), 760),
      ],
      totalCalories: 2380,
      totalProteinG: 132,
      totalCarbsG: 268,
      totalFatG: 81,
      dailyCalorieGoal: 2000,
    ),
    plan: const DietPlanLoaded(
      MealPlan(
        meals: [
          Meal(
            name: 'Breakfast',
            items: [],
            calories: 500,
            protein: 30,
            carbs: 60,
            fat: 15,
          ),
          Meal(
            name: 'Lunch',
            items: [],
            calories: 700,
            protein: 45,
            carbs: 80,
            fat: 20,
          ),
          Meal(
            name: 'Dinner',
            items: [],
            calories: 600,
            protein: 40,
            carbs: 60,
            fat: 20,
          ),
          Meal(
            name: 'Snack',
            items: [],
            calories: 200,
            protein: 10,
            carbs: 25,
            fat: 7,
          ),
        ],
        totalCalories: 2000,
        totalProtein: 125,
        totalCarbs: 225,
        totalFat: 62,
      ),
    ),
    screenTime: const ScreenTimeLoaded(
      usageStats: [],
      totalDuration: Duration(hours: 5, minutes: 10),
    ),
    weight: TrendData<WeightLogCache>(
      TrendSeries([DailyPoint(today, 72.4)], goal: 70),
      [_weight(72.4, today.subtract(const Duration(days: 7)))],
    ),
    profile: base.profile,
  );
}

/// Every card still loading (first open, no cached data).
_Scenario _loading() => _Scenario(
  name: 'loading',
  water: WaterIntakeLoading(),
  sleep: SleepLoading(),
  mood: const StressCheckInState(),
  goals: const ActivityGoalsState(),
  meals: const MealLogLoading(),
  plan: DietPlanInitial(),
  screenTime: ScreenTimeLoading(),
  weight: null,
  profile: ProfileInitial(),
);

/// Every card failed to load (offline, nothing cached).
_Scenario _error() => _Scenario(
  name: 'error',
  water: const WaterIntakeError('offline'),
  sleep: const SleepError('offline'),
  mood: const StressCheckInState(),
  goals: const ActivityGoalsState(loading: false, failed: true),
  meals: const MealLogError('offline'),
  plan: DietPlanInitial(),
  screenTime: const ScreenTimeError('offline'),
  weight: null,
  weightError: 'offline',
);

Widget _providers(_Scenario s, Widget child) => MultiBlocProvider(
  providers: [
    BlocProvider<ProfileCubit>(create: (_) => _FakeProfile(s.profile)),
    BlocProvider<WaterIntakeCubit>(create: (_) => _FakeWater(s.water)),
    BlocProvider<SleepCubit>(create: (_) => _FakeSleep(s.sleep)),
    BlocProvider<StressCheckInCubit>(create: (_) => _FakeStress(s.mood)),
    BlocProvider<ActivityGoalsCubit>(create: (_) => _FakeGoals(s.goals)),
    BlocProvider<MealLogBloc>(create: (_) => _FakeMeals(s.meals)),
    BlocProvider<DietPlanCubit>(create: (_) => _FakeDietPlan(s.plan)),
    BlocProvider<ScreenTimeCubit>(create: (_) => _FakeScreenTime(s.screenTime)),
    BlocProvider<TrendCubit<WaterLogCache>>(
      create: (_) => _FixedTrend<WaterLogCache>(
        const TrendData<WaterLogCache>(TrendSeries([], goal: 2500)),
      ),
    ),
    BlocProvider<TrendCubit<WeightLogCache>>(
      create: (_) =>
          _FixedTrend<WeightLogCache>(s.weight, error: s.weightError),
    ),
    BlocProvider<TrendCubit<SleepSessionInfo>>(
      create: (_) => _FixedTrend<SleepSessionInfo>(
        const TrendData<SleepSessionInfo>(TrendSeries([], goal: 480)),
      ),
    ),
    BlocProvider<TrendCubit<MealLogEntry>>(
      create: (_) => _FixedTrend<MealLogEntry>(
        const TrendData<MealLogEntry>(TrendSeries([], goal: 2000)),
      ),
    ),
  ],
  child: child,
);

/// The feed on the app background, inside a boundary for the screenshot.
Widget _page(_Scenario s) => _providers(
  s,
  Scaffold(
    backgroundColor: Colors.transparent,
    body: SingleChildScrollView(
      child: RepaintBoundary(
        key: _shotKey,
        child: Builder(
          builder: (context) => DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              image: const DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: context.pagePadding.copyWith(
                top: AppDimens.sectionGap,
                bottom: AppDimens.sectionGap,
              ),
              child: ResponsiveCenter(child: homeFeed()),
            ),
          ),
        ),
      ),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Fonts, images and capture
// ---------------------------------------------------------------------------

/// Lets asset loads (background image, SVG icons) finish and the cards'
/// progress animations run to the end.
Future<void> _settleAssets(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _capture(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shotKey),
    );
    final image = await boundary.toImage(pixelRatio: _shotPixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

typedef _Case = ({double width, double scale, bool dark});

const List<_Case> _cases = [
  (width: 360, scale: 1.0, dark: false),
  // The largest text size before half-width tiles stack.
  (width: 360, scale: 1.15, dark: false),
  (width: 360, scale: 1.25, dark: false),
  (width: 384, scale: 1.25, dark: false),
  (width: 384, scale: 1.3, dark: false),
  (width: 384, scale: kMaxTextScale, dark: false),
  (width: 360, scale: 1.3, dark: false),
  (width: 360, scale: kMaxTextScale, dark: false),
  (width: 412, scale: 1.0, dark: false),
  (width: 412, scale: 1.15, dark: false),
  (width: 412, scale: 1.25, dark: false),
  (width: 412, scale: kMaxTextScale, dark: false),
  (width: 412, scale: 1.0, dark: true),
  (width: 412, scale: kMaxTextScale, dark: true),
  // Tablet: content capped at the max width, centred.
  (width: 800, scale: 1.0, dark: false),
];

String _scaleName(double s) =>
    s.toStringAsFixed(s * 10 == (s * 10).roundToDouble() ? 1 : 2);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<ScreenTimeService>(_FakeScreenTimeService());
  });

  tearDown(() async {
    await sl.reset();
  });

  for (final scenario in [
    _typical,
    _long,
    _empty,
    _states,
    _loading,
    _error,
    _noGoals,
  ]) {
    for (final c in _cases) {
      final s = scenario();
      final theme = c.dark ? 'dark' : 'light';
      final id = '${s.name}_${c.width.round()}_${_scaleName(c.scale)}_$theme';

      testWidgets('home cards: $id', (tester) async {
        sl.registerSingleton<SleepService>(
          _FakeSleepService(s.sleepGoalMinutes),
        );
        sl.registerSingleton<WeightService>(
          _FakeWeightService(s.weightUnit, s.weight?.logs ?? const []),
        );
        await tester.runAsync(loadAllFonts);
        await pumpPage(
          tester,
          _page(s),
          textScale: c.scale,
          size: Size(c.width, _canvasHeight),
          theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/bg.png'),
            tester.element(find.byKey(_shotKey)),
          ),
        );
        await _settleAssets(tester);

        final errors = takeAllExceptions(tester);
        final cut = truncatedTexts(tester);
        final shrunk = shrunkTexts(tester);
        final feedHeight = tester.getSize(find.byKey(_shotKey)).height;

        if (_writeShots) {
          await _capture(tester, 'build/home_shots/$id.png');
        }

        final report = StringBuffer();
        if (feedHeight > _canvasHeight) {
          report.writeln(
            '  feed is ${feedHeight.round()} dp, taller than the '
            '${_canvasHeight.round()} dp canvas',
          );
        }
        for (final e in errors) {
          report.writeln('  exception: ${e.toString().split('\n').first}');
        }
        for (final t in cut) {
          report.writeln('  truncated: $t');
        }
        for (final t in shrunk) {
          report.writeln('  shrunk: $t');
        }
        if (report.isNotEmpty) {
          // ignore: avoid_print
          print('[home_cards] $id\n$report');
        }

        if (_strict) {
          expect(errors, isEmpty, reason: 'layout exceptions in $id');
          expect(cut, isEmpty, reason: 'truncated texts in $id');
          expect(
            shrunk,
            isEmpty,
            reason: 'texts drawn below their size in $id',
          );
        }
      });
    }
  }
}
