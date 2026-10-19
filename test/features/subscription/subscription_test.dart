import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/subscription/data/services/store_billing.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/pages/pro_page.dart';
import 'package:vital_up/features/subscription/presentation/widgets/pro_paywall.dart';

import '../../helpers/pump_app.dart';

const _yearly = ProPlan(
  id: r'$rc_annual',
  period: ProPlanPeriod.annual,
  price: '₹1,499.00',
  pricePerMonth: '₹124.92',
  trialDays: 7,
  savingsPercent: 37,
);
const _monthly = ProPlan(
  id: r'$rc_monthly',
  period: ProPlanPeriod.monthly,
  price: '₹199.00',
);

class _FakeRepository implements SubscriptionRepository {
  @override
  bool canPurchase;
  ProStatus current;
  List<ProPlan> offered = const [_yearly, _monthly];
  PurchaseOutcome next = const PurchaseCancelled();
  Object? statusError;
  final identified = <String?>[];
  final purchased = <String>[];
  final _changes = StreamController<ProStatus>.broadcast();

  _FakeRepository({
    this.canPurchase = true,
    this.current = ProStatus.free,
  });

  @override
  Future<void> identify(String? userId) async => identified.add(userId);

  @override
  Future<ProStatus> status({bool forceRefresh = false}) async {
    final error = statusError;
    if (error != null) throw error;
    return current;
  }

  @override
  Stream<ProStatus> get changes => _changes.stream;

  void storeChanged(ProStatus status) {
    current = status;
    _changes.add(status);
  }

  @override
  Future<List<ProPlan>> plans() async => offered;

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    purchased.add(planId);
    return next;
  }

  @override
  Future<PurchaseOutcome> restore() async => next;

  @override
  Future<void> syncServer() async {}

  @override
  Future<int> remainingFreeScans() async => 5;
}

void main() {
  group('SubscriptionCubit', () {
    late StreamController<String?> users;
    late _FakeRepository repo;
    late SubscriptionCubit cubit;

    setUp(() {
      users = StreamController<String?>();
      repo = _FakeRepository();
      cubit = SubscriptionCubit(repo, userIds: users.stream)..start();
    });

    tearDown(() async {
      await cubit.close();
      await users.close();
    });

    test('reads the plan on sign-in and drops to free on sign-out', () async {
      repo.current = const ProStatus(isPro: true, productId: 'pro:yearly');
      users.add('u1');
      await pumpEventQueue();
      expect(repo.identified, ['u1']);
      expect(cubit.state.isPro, isTrue);
      expect(cubit.state.loaded, isTrue);

      users.add(null);
      await pumpEventQueue();
      expect(repo.identified, ['u1', null]);
      expect(cubit.state.isPro, isFalse);
      expect(cubit.state.loaded, isFalse);
      expect(cubit.state.canPurchase, isTrue);
    });

    test('a failed refresh keeps the plan shown', () async {
      repo.current = const ProStatus(isPro: true);
      users.add('u1');
      await pumpEventQueue();
      repo.statusError = Exception('offline');
      await cubit.refresh(force: true);
      expect(cubit.state.isPro, isTrue);
    });

    test('store changes re-read the plan', () async {
      users.add('u1');
      await pumpEventQueue();
      expect(cubit.state.isPro, isFalse);
      repo.storeChanged(const ProStatus(isPro: true));
      await pumpEventQueue();
      expect(cubit.state.isPro, isTrue);
    });

    test('a completed purchase turns Pro on; one purchase at a time', () async {
      users.add('u1');
      await pumpEventQueue();
      repo.next = const PurchaseCompleted(ProStatus(isPro: true));
      final first = cubit.purchase(_yearly.id);
      expect(cubit.state.buyingPlanId, _yearly.id);
      expect(await cubit.purchase(_monthly.id), isNull);
      expect(await first, isA<PurchaseCompleted>());
      expect(repo.purchased, [_yearly.id]);
      expect(cubit.state.isPro, isTrue);
      expect(cubit.state.busy, isFalse);
    });

    test('cancelled or failed purchases leave the plan free', () async {
      users.add('u1');
      await pumpEventQueue();
      repo.next = const PurchaseCancelled();
      expect(await cubit.purchase(_yearly.id), isA<PurchaseCancelled>());
      repo.next = const PurchaseFailed('No');
      expect(await cubit.restore(), isA<PurchaseFailed>());
      expect(cubit.state.isPro, isFalse);
      expect(cubit.state.busy, isFalse);
    });

    test('plans: loaded once, empty offering is an error', () async {
      await cubit.loadPlans();
      expect(cubit.state.plans, [_yearly, _monthly]);
      repo.offered = const [];
      await cubit.loadPlans();
      expect(cubit.state.plans, [_yearly, _monthly]);
      await cubit.loadPlans(force: true);
      expect(cubit.state.plans, isEmpty);
      expect(cubit.state.plansError, isNotNull);
    });

    test('no plans are loaded where Pro can\'t be bought', () async {
      final noStore = SubscriptionCubit(
        _FakeRepository(canPurchase: false),
        userIds: const Stream.empty(),
      );
      await noStore.loadPlans();
      expect(noStore.state.plans, isEmpty);
      expect(noStore.state.plansError, isNull);
      expect(noStore.state.canUpgrade, isFalse);
      await noStore.close();
    });
  });

  test('yearly savings: whole percent, none when tiny or mixed', () {
    expect(
      RevenueCatBilling.yearlySavingsPercent(monthly: 199, yearly: 1499),
      37,
    );
    expect(
      RevenueCatBilling.yearlySavingsPercent(monthly: 100, yearly: 1180),
      isNull,
    );
    expect(
      RevenueCatBilling.yearlySavingsPercent(
        monthly: 199,
        yearly: 1499,
        sameCurrency: false,
      ),
      isNull,
    );
  });

  test('plan line says when Pro renews or ends', () {
    final end = DateTime(2027, 11, 12);
    expect(
      ProStatusCard.describe(
        ProStatus(isPro: true, productId: 'pro:yearly', expiresAt: end),
      ),
      'Yearly plan, renews 12 Nov 2027',
    );
    expect(
      ProStatusCard.describe(
        ProStatus(
          isPro: true,
          productId: 'pro:monthly',
          expiresAt: end,
          willRenew: false,
        ),
      ),
      'Monthly plan, ends 12 Nov 2027',
    );
    expect(
      ProStatusCard.describe(
        ProStatus(isPro: true, isTrial: true, expiresAt: end),
      ),
      'Free trial, paid plan starts 12 Nov 2027',
    );
  });

  group('paywall', () {
    Future<SubscriptionCubit> pump(
      WidgetTester tester,
      Widget child, {
      _FakeRepository? repo,
      double textScale = 1.0,
    }) async {
      // Signed in, like every page that shows the paywall.
      final cubit = SubscriptionCubit(
        repo ?? _FakeRepository(),
        userIds: Stream.value('u1'),
      )..start();
      addTearDown(cubit.close);
      await pumpPage(
        tester,
        BlocProvider.value(value: cubit, child: child),
        textScale: textScale,
      );
      await settle(tester);
      return cubit;
    }

    testWidgets('shows plans, yearly picked, with renewal terms', (
      tester,
    ) async {
      await pump(tester, const ProPage());
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('7 days free'), findsOneWidget);
      expect(find.text('Save 37%'), findsOneWidget);
      expect(find.text('Start free trial'), findsOneWidget);
      expect(
        find.text(
          'Free for 7 days, then ₹1,499.00 a year. Renews automatically '
          'until you cancel in Google Play.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Monthly'));
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      expect(find.text('Subscribe'), findsOneWidget);
    });

    testWidgets('buying the picked plan', (tester) async {
      final repo = _FakeRepository()
        ..next = const PurchaseCompleted(ProStatus(isPro: true));
      await pump(tester, const ProPage(), repo: repo);
      await tester.ensureVisible(find.text('Monthly'));
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      await tester.ensureVisible(find.text('Subscribe'));
      await tester.tap(find.text('Subscribe'));
      await settle(tester);
      expect(repo.purchased, [_monthly.id]);
      expect(find.text("You're on VitalUp Pro"), findsOneWidget);
    });

    testWidgets('limit reason in the sheet header', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showProPaywall(context, reason: ProReason.photoScans),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text(ProReason.photoScans.title), findsOneWidget);
    });

    testWidgets('no store: benefits only, no buy button', (tester) async {
      await pump(
        tester,
        const ProPage(),
        repo: _FakeRepository(canPurchase: false),
      );
      expect(find.text("Pro isn't available on this device yet."), findsOne);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Start free trial'), findsNothing);
    });

    for (final pro in [false, true]) {
      testWidgets('fits a small phone at the largest text (Pro: $pro)', (
        tester,
      ) async {
        final repo = _FakeRepository(
          current: pro
              ? ProStatus(
                  isPro: true,
                  productId: 'pro:yearly',
                  expiresAt: DateTime(2027, 11, 12),
                )
              : ProStatus.free,
        );
        await pump(
          tester,
          const ProPage(),
          repo: repo,
          textScale: kMaxTextScale,
        );
        expect(
          find.text("You're on VitalUp Pro"),
          pro ? findsOneWidget : findsNothing,
        );
        expect(takeAllExceptions(tester), isEmpty);
        expect(truncatedTexts(tester), isEmpty);
      });
    }
  });
}
