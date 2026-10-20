import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/quota_reset.dart';
import 'package:vital_up/features/subscription/data/services/ai_quota_service.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/ai_quota_line.dart';

import '../../helpers/pump_app.dart';

class _Plans implements SubscriptionRepository {
  @override
  final bool canPurchase;
  final ProStatus current;

  _Plans({this.canPurchase = true, this.current = ProStatus.free});

  @override
  Future<ProStatus> status({bool forceRefresh = false}) async => current;

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

late Directory _dir;

/// Lets the cache's real file reads finish (they don't run on the test's
/// fake clock), a frame at a time.
Future<void> _settleIo(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// A service whose server read says [used] for every feature.
AiQuotaService _service({int used = 0, List<String>? reads}) => AiQuotaService(
  CacheStore(ConnectivityService(), directory: _dir),
  userId: () => 'u1',
  usedOn: (userId, feature, day) async {
    reads?.add('$feature@$day');
    return used;
  },
);

void main() {
  setUp(() => _dir = Directory.systemTemp.createTempSync('ai_quota'));
  tearDown(() {
    // Windows may still hold a cache file for a moment.
    try {
      _dir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  group('AiQuotaService', () {
    test('first read counts today\'s usage against the free limit', () async {
      final reads = <String>[];
      final service = _service(used: 4, reads: reads);
      expect(await service.freeLeft(AiQuota.vitaChat), 11);
      expect(reads, ['vita_chat@${serverQuotaDay()}']);
      // Cached for a while: no second request.
      expect(await service.freeLeft(AiQuota.vitaChat), 11);
      expect(reads, hasLength(1));
    });

    test('the server\'s count after a use wins and is announced', () async {
      final service = _service(used: 4);
      final announced = <void>[];
      final sub = service.changes(AiQuota.vitaChat).listen(announced.add);
      await service.report(AiQuota.vitaChat, 7);
      await pumpEventQueue();
      expect(await service.freeLeft(AiQuota.vitaChat), 7);
      expect(announced, hasLength(1));
      await sub.cancel();
    });

    test('counts stay within the free allowance', () async {
      final service = _service(used: 40);
      expect(await service.freeLeft(AiQuota.dietPlan), 0);
      await service.report(AiQuota.dietPlan, 140); // a Pro count
      expect(await service.freeLeft(AiQuota.dietPlan), 3);
    });

    test('a count saved on an earlier server day reads as reset', () async {
      final cache = CacheStore(ConnectivityService(), directory: _dir);
      await cache.write(AiQuotaService.cacheKey(AiQuota.vitaChat, 'u1'), {
        'day': '2001-01-01',
        'left': 0,
      });
      final service = AiQuotaService(
        cache,
        userId: () => 'u1',
        usedOn: (_, _, _) async => 0,
      );
      expect(await service.freeLeft(AiQuota.vitaChat), 15);
    });

    test('unknown when signed out or the read fails', () async {
      final signedOut = AiQuotaService(
        CacheStore(ConnectivityService(), directory: _dir),
        userId: () => null,
        usedOn: (_, _, _) async => 0,
      );
      expect(await signedOut.freeLeft(AiQuota.vitaChat), isNull);
      final failing = AiQuotaService(
        CacheStore(ConnectivityService(), directory: _dir),
        userId: () => 'u1',
        usedOn: (_, _, _) async => throw StateError('server down'),
      );
      expect(await failing.freeLeft(AiQuota.vitaChat), isNull);
    });
  });

  group('AiQuotaLine', () {
    test('wording', () {
      expect(
        AiQuotaLine.describe(AiQuota.vitaChat, 12),
        '12 of 15 messages left today',
      );
      expect(
        AiQuotaLine.describe(AiQuota.dietPlan, 1),
        '1 of 3 AI plans left today',
      );
      expect(
        AiQuotaLine.describe(AiQuota.vitaChat, 0),
        startsWith('No messages left today. More at '),
      );
    });

    Future<void> pump(
      WidgetTester tester,
      AiQuotaService service, {
      _Plans? plans,
      double textScale = 1.0,
      ThemeData? theme,
    }) async {
      final cubit = SubscriptionCubit(
        plans ?? _Plans(),
        userIds: Stream.value('u1'),
      )..start();
      addTearDown(cubit.close);
      await pumpPage(
        tester,
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Center(
              child: AiQuotaLine(quota: AiQuota.vitaChat, service: service),
            ),
          ),
        ),
        textScale: textScale,
        theme: theme,
      );
      await _settleIo(tester);
    }

    testWidgets('free: count and the Pro link, fitting the largest text', (
      tester,
    ) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await pump(
          tester,
          _service(used: 3),
          textScale: kMaxTextScale,
          theme: theme,
        );
        expect(find.text('12 of 15 messages left today'), findsOneWidget);
        expect(find.text('Get more with Pro'), findsOneWidget);
        expect(truncatedTexts(tester), isEmpty);
        expect(takeAllExceptions(tester), isEmpty);
      }
    });

    testWidgets('follows a use reported by the server', (tester) async {
      final service = _service(used: 3);
      await pump(tester, service);
      await tester.runAsync(() => service.report(AiQuota.vitaChat, 0));
      await _settleIo(tester);
      expect(find.textContaining('No messages left today'), findsOneWidget);
    });

    testWidgets('no Pro link where Pro can\'t be bought', (tester) async {
      await pump(tester, _service(used: 3), plans: _Plans(canPurchase: false));
      expect(find.text('12 of 15 messages left today'), findsOneWidget);
      expect(find.text('Get more with Pro'), findsNothing);
    });

    testWidgets('hidden with Pro', (tester) async {
      await pump(
        tester,
        _service(used: 3),
        plans: _Plans(current: const ProStatus(isPro: true)),
      );
      expect(find.textContaining('left today'), findsNothing);
    });
  });
}
