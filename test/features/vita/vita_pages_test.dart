import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/features/subscription/data/services/ai_quota_service.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/generate_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/set_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/vita/data/services/vita_ai_consent.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/cubit/vita_chat_cubit.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_chat_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_diet_plan_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_health_analysis_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_home_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_stress_guide_page.dart';

import '../../helpers/pump_app.dart';

/// Noon yesterday (calendar step, safe across a clock change).
final _yesterday = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - 1, 12);
}();

class _FakeVita implements VitaRepository {
  List<VitaMessage> history;

  _FakeVita({this.history = const []});

  static final greeting = VitaMessage(
    sender: VitaSender.vita,
    text: "Hi, I'm Vita. What's on your mind today?",
    sentAt: DateTime.now(),
  );

  @override
  Future<List<VitaMessage>> loadHistory() async =>
      history.isEmpty ? [greeting] : history;

  @override
  Future<void> saveHistory(List<VitaMessage> messages) async {
    history = messages;
  }

  @override
  String get chatOwnerId => 'user';

  double? scroll;

  @override
  double? readChatScroll() => scroll;

  @override
  Future<void> saveChatScroll(double? offsetFromEnd) async {
    scroll = offsetFromEnd;
  }

  @override
  Future<VitaMessage> reply(
    List<VitaMessage> history, {
    MealPlan? draftPlan,
  }) async => VitaMessage(
    sender: VitaSender.vita,
    text: 'Try a short walk after dinner.',
    sentAt: DateTime.now(),
  );

  @override
  Future<HealthAnalysis> getHealthAnalysis() async => const HealthAnalysis(
    headline: 'Your sleep has been short this week, which can raise stress.',
    signals: [
      HealthSignal(
        kind: HealthSignalKind.diet,
        title: 'Diet & nutrition',
        summary: '1,850 kcal a day on average, 18% under your goal',
      ),
      HealthSignal(
        kind: HealthSignalKind.sleep,
        title: 'Sleep',
        summary: '6h 10m a night on average, 1h 50m under your goal',
      ),
      HealthSignal(
        kind: HealthSignalKind.metrics,
        title: 'Health metrics',
        summary: 'Resting heart rate 64 bpm, steady this week',
      ),
    ],
  );

  @override
  Future<StressReport> getStressReport() async => const StressReport(
    score: 62,
    level: StressLevel.moderate,
    source: StressSource.estimated,
    trend: 'Up 8 points from yesterday',
    triggers: [
      StressTrigger(
        name: 'Short sleep last night',
        severity: TriggerSeverity.high,
      ),
      StressTrigger(
        name: 'Over 5 hours of screen time',
        severity: TriggerSeverity.medium,
      ),
    ],
    tip: 'Try four slow breaths before bed tonight.',
  );

  @override
  Future<void> saveStressCheckIn(
    int level, {
    List<StressTag> tags = const [],
  }) async {}

  @override
  List<StressCheckIn> getStressCheckIns() => const [];

  @override
  Future<VitaDailyInsights?> getDailyInsights() async => null;

  @override
  Future<void> reload() async {}
}

/// The active plan: breakfast offers two other dishes, lunch none.
class _FakePlans implements DietPlanRepository {
  MealPlan? active = const MealPlan(
    meals: [
      Meal(
        name: 'Breakfast',
        items: ['2 Besan Chilla', '1 Cup Curd'],
        calories: 400,
        protein: 20,
        carbs: 45,
        fat: 12,
        alternatives: [
          MealOption(
            items: ['1 Bowl Vegetable Upma'],
            calories: 380,
            protein: 12,
            carbs: 55,
            fat: 10,
          ),
          MealOption(
            items: ['2 Moong Dal Dosa', '1 Bowl Sambar'],
            calories: 430,
            protein: 22,
            carbs: 50,
            fat: 12,
          ),
        ],
      ),
      Meal(
        name: 'Lunch',
        items: ['2 Roti', '1 Bowl Palak Dal', '1 Cup Curd'],
        calories: 600,
        protein: 25,
        carbs: 80,
        fat: 15,
      ),
    ],
    totalCalories: 1000,
    totalProtein: 45,
    totalCarbs: 125,
    totalFat: 27,
  );

  @override
  Future<MealPlan?> getActiveMealPlan() async => active;

  @override
  Future<Map<String, dynamic>> getActivePlanPreferences() async => const {};

  @override
  Future<void> setActiveMealPlan(
    MealPlan plan, {
    Map<String, dynamic> preferences = const {},
  }) async {
    active = plan;
  }

  @override
  Future<ApiResult<MealPlan>> generateMealPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
    String? instructions,
    MealPlan? basePlan,
  }) async => ApiSuccess(active!);
}

/// A free account that can buy Pro.
class _FreePlan implements SubscriptionRepository {
  @override
  bool get canPurchase => true;

  @override
  Future<ProStatus> status({bool forceRefresh = false}) async => ProStatus.free;

  @override
  Future<void> identify(String? userId) async {}

  @override
  Stream<ProStatus> get changes => const Stream.empty();

  @override
  Future<List<ProPlan>> plans() async => const [];

  @override
  Future<PurchaseOutcome> purchase(String planId) async =>
      const PurchaseCancelled();

  @override
  Future<PurchaseOutcome> restore() async => const PurchaseCancelled();

  @override
  Future<void> syncServer() async {}

  @override
  Future<int> remainingFreeScans() async => 5;

  @override
  Stream<void> get remainingScansChanges => const Stream.empty();
}

Future<_FakeVita> _register({List<VitaMessage> history = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final consent = VitaAiConsent(
    await SharedPreferences.getInstance(),
    userId: () => 'u1',
  );
  await consent.accept(includeHealthConnect: false);
  final repo = _FakeVita(history: history);
  await sl.reset();
  sl.registerSingleton<VitaAiConsent>(consent);
  sl.registerSingleton<VitaRepository>(repo);
  sl.registerFactory(() => VitaChatCubit(sl<VitaRepository>()));
  final plans = _FakePlans();
  sl.registerSingleton<_FakePlans>(plans);
  sl.registerFactory(
    () => DietPlanCubit(
      generateMealPlan: GenerateMealPlan(plans),
      getActiveMealPlan: GetActiveMealPlan(plans),
      setActiveMealPlan: SetActiveMealPlan(plans),
    ),
  );
  addTearDown(sl.reset);
  return repo;
}

/// Every Vita page at 1.0 and the largest text size, light and dark:
/// nothing cut, clipped or overflowing.
Future<void> _expectFits(
  WidgetTester tester,
  Widget Function() page, {
  Set<String> previews = const {},
}) async {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final scale in [1.0, kMaxTextScale]) {
      await pumpPage(tester, page(), textScale: scale, theme: theme);
      await settle(tester);
      expect(
        takeAllExceptions(tester),
        isEmpty,
        reason: 'text $scale, ${theme.brightness.name}',
      );
      expect(
        truncatedTexts(tester, previews: previews),
        isEmpty,
        reason: 'text $scale, ${theme.brightness.name}',
      );
    }
  }
}

void main() {
  testWidgets('Vita tab: intro, chat button, three pages, AI note', (
    tester,
  ) async {
    await _register();
    await _expectFits(tester, () => const VitaHomePage());
    expect(find.text('Meet Vita'), findsOneWidget);
    expect(find.text('Chat with Vita'), findsOneWidget);
    for (final title in ['Diet plan', 'Health analysis', 'Stress guide']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('chat: suggestions only before the first question', (
    tester,
  ) async {
    await _register();
    await pumpPage(tester, const VitaChatPage());
    await settle(tester);
    expect(find.text('How am I doing this week?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('How am I doing this week?'));
    await settle(tester);
    expect(find.text('Try a short walk after dinner.'), findsOneWidget);
    // Sent as a message; the other suggestions are gone.
    expect(find.text('How am I doing this week?'), findsOneWidget);
    expect(find.text('Help me sleep better'), findsNothing);
  });

  testWidgets('chat: one day label per day and clearing asks first', (
    tester,
  ) async {
    final repo = await _register(
      history: [
        VitaMessage(
          sender: VitaSender.user,
          text: 'How was my sleep?',
          sentAt: _yesterday,
        ),
        VitaMessage(
          sender: VitaSender.vita,
          text: 'You slept 6h 10m, a little under your goal.',
          bullets: const ['Go to bed 30 minutes earlier tonight'],
          action: VitaAction.viewAnalysis,
          sentAt: _yesterday,
        ),
        VitaMessage(
          sender: VitaSender.user,
          text: 'And today?',
          sentAt: DateTime.now(),
        ),
      ],
    );
    await _expectFits(tester, () => const VitaChatPage());
    // Opens at the latest message; older days are above it.
    expect(find.text('And today?'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Yesterday'),
      find.byType(ListView),
      const Offset(0, 200),
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('View health analysis'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear chat'));
    await tester.pumpAndSettle();
    expect(find.text('Clear this chat?'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(repo.history, isEmpty);
    expect(find.text('How was my sleep?'), findsNothing);
    expect(find.text(_FakeVita.greeting.text), findsOneWidget);
  });

  testWidgets('chat reopens where it was left, already in place', (
    tester,
  ) async {
    final repo = await _register(
      history: [
        for (var i = 0; i < 30; i++)
          VitaMessage(
            sender: i.isEven ? VitaSender.user : VitaSender.vita,
            text: 'Message $i',
            sentAt: DateTime.now(),
          ),
      ],
    );
    repo.scroll = 300;
    await pumpPage(tester, const VitaChatPage());
    await settle(tester);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.controller!.offset, 300);

    // Scrolled back to the latest message: nothing to remember.
    list.controller!.jumpTo(0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(repo.scroll, isNull);
  });

  testWidgets('health analysis fits and reads plainly', (tester) async {
    await _register();
    await _expectFits(tester, () => const VitaHealthAnalysisPage());
    expect(find.text('Your health at a glance'), findsOneWidget);
    expect(find.text('Based on 3 areas you track'), findsOneWidget);
  });

  testWidgets('stress guide fits with triggers and tip', (tester) async {
    await _register();
    await _expectFits(tester, () => const VitaStressGuidePage());
    expect(find.text('Moderate stress'), findsOneWidget);
    expect(find.text('Possible triggers today'), findsOneWidget);
    // Heart data isn't read (Play minimum scope): no watch card.
    expect(find.text('Connect watch data'), findsNothing);
  });

  testWidgets('diet plan: fits, and a swap from the options sheet is saved', (
    tester,
  ) async {
    await _register();
    await _expectFits(tester, () => const VitaDietPlanPage());
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    final editAction = tester.widget<AppHeaderAction>(
      find.byWidgetPredicate(
        (w) => w is AppHeaderAction && w.tooltip == 'Edit plan',
      ),
    );
    expect(editAction.svgAsset, 'assets/icons/ui/edit.svg');
    expect(find.text('2 other options'), findsOneWidget); // breakfast only

    await tester.tap(find.text('2 other options'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use').first);
    await tester.tap(find.text('Use').first);
    await settle(tester);

    final saved = sl<_FakePlans>().active!;
    expect(saved.meals[0].items, ['1 Bowl Vegetable Upma']);
    expect(saved.totalCalories, 980);
    expect(find.text('1 Bowl Vegetable Upma'), findsOneWidget);
    expect(find.text('Breakfast updated.'), findsOneWidget);
  });

  /// The chat as a free user who has used [used] of today's messages.
  Future<void> openChatAfter(WidgetTester tester, int used) async {
    await _register();
    final dir = Directory.systemTemp.createTempSync('vita_quota');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    sl.registerSingleton(
      AiQuotaService(
        CacheStore(ConnectivityService(), directory: dir),
        userId: () => 'u1',
        usedOn: (_, _, _) async => used,
      ),
    );
    final plan = SubscriptionCubit(_FreePlan(), userIds: Stream.value('u1'))
      ..start();
    addTearDown(plan.close);
    await pumpPage(
      tester,
      BlocProvider.value(value: plan, child: const VitaChatPage()),
      textScale: kMaxTextScale,
    );
    // The count is read from files, which don't run on the fake clock.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('chat: messages left show with the Pro link', (tester) async {
    await openChatAfter(tester, 12);
    expect(find.text('3 of 15 messages left today'), findsOneWidget);
    expect(find.text('Get more with Pro'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(truncatedTexts(tester), isEmpty);
  });

  testWidgets('chat: at 0 the composer locks and says why', (tester) async {
    await openChatAfter(tester, 15);
    // The line and the composer's hint.
    expect(find.textContaining('No messages left today'), findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Get more with Pro'), findsOneWidget);
    expect(truncatedTexts(tester), isEmpty);
  });
}
