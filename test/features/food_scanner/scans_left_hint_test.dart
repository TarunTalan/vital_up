import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/scans_left_hint.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';

import '../../helpers/pump_app.dart';

class _FakeRepository implements SubscriptionRepository {
  @override
  final bool canPurchase;
  ProStatus current;
  int left;
  Object? leftError;
  final _scanChanges = StreamController<void>.broadcast();

  _FakeRepository({
    this.canPurchase = true,
    this.current = ProStatus.free,
    this.left = 5,
  });

  void scanUsed() {
    left -= 1;
    _scanChanges.add(null);
  }

  @override
  Future<int> remainingFreeScans() async {
    final error = leftError;
    if (error != null) throw error;
    return current.isPro ? -1 : left;
  }

  @override
  Stream<void> get remainingScansChanges => _scanChanges.stream;

  @override
  Future<void> identify(String? userId) async {}

  @override
  Future<ProStatus> status({bool forceRefresh = false}) async => current;

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
}

Future<SubscriptionCubit> _pump(
  WidgetTester tester,
  _FakeRepository repo, {
  double textScale = 1.0,
}) async {
  final cubit = SubscriptionCubit(repo, userIds: Stream.value('u1'))..start();
  addTearDown(cubit.close);
  await pumpPage(
    tester,
    BlocProvider.value(
      value: cubit,
      child: Scaffold(
        body: Center(child: ScansLeftHint(repository: repo)),
      ),
    ),
    textScale: textScale,
  );
  await tester.pump();
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets('shows scans left and follows each scan', (tester) async {
    final repo = _FakeRepository(left: 2);
    await _pump(tester, repo);
    expect(find.text('2 photo scans left today'), findsOneWidget);

    repo.scanUsed();
    await tester.pump();
    await tester.pump();
    expect(find.text('1 photo scan left today'), findsOneWidget);

    repo.scanUsed();
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        'No photo scans left today. Barcodes still work. Get more with Pro',
      ),
      findsOneWidget,
    );
  });

  testWidgets('at zero without a store there is no Pro offer', (tester) async {
    await _pump(tester, _FakeRepository(left: 0, canPurchase: false));
    expect(
      find.text('No photo scans left today. Barcodes still work.'),
      findsOneWidget,
    );
  });

  testWidgets('hidden with Pro', (tester) async {
    await _pump(tester, _FakeRepository(current: const ProStatus(isPro: true)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('hidden while the count is unknown', (tester) async {
    final repo = _FakeRepository()..leftError = Exception('offline');
    await _pump(tester, repo);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('whole at the largest text size', (tester) async {
    await _pump(tester, _FakeRepository(left: 0), textScale: kMaxTextScale);
    expect(truncatedTexts(tester), isEmpty);
  });
}
