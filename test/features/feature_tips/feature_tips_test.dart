import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/feature_tip_card.dart';
import 'package:vital_up/features/feature_tips/data/feature_tips_service.dart';
import 'package:vital_up/features/feature_tips/domain/feature_tip.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';

import '../../helpers/pump_app.dart';

class _FakeScheduler implements TipScheduler {
  bool? allowed = true;
  final List<(String, DateTime)> scheduled = [];
  int cancels = 0;

  @override
  Future<bool?> permitted() async => allowed;

  @override
  Future<void> schedule(FeatureTip tip, DateTime at) async =>
      scheduled.add((tip.id, at));

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  group('FeatureTipRules.next', () {
    final installed = DateTime(2026, 10, 1, 9);

    test('waits a few days after install', () {
      final next = FeatureTipRules.next(
        now: DateTime(2026, 10, 1, 9),
        installedAt: installed,
        shown: {},
        usedRoutes: {},
        random: Random(1),
      )!;
      expect(next.at.isBefore(DateTime(2026, 10, 4)), isFalse);
      expect(next.at.isBefore(DateTime(2026, 10, 5)), isTrue);
    });

    test('a week after the last tip, in the afternoon window', () {
      for (var seed = 0; seed < 50; seed++) {
        final next = FeatureTipRules.next(
          now: DateTime(2026, 10, 20, 8),
          installedAt: installed,
          lastTipAt: DateTime(2026, 10, 19, 15),
          shown: {'offline_maps'},
          usedRoutes: {},
          random: Random(seed),
        )!;
        expect(next.at.day, 26);
        expect(next.at.hour, inInclusiveRange(11, 18));
        expect(next.tip.id, isNot('offline_maps'));
      }
    });

    test('today, but not within half an hour or after the window', () {
      final now = DateTime(2026, 10, 20, 15, 10);
      for (var seed = 0; seed < 50; seed++) {
        final next = FeatureTipRules.next(
          now: now,
          installedAt: installed,
          shown: {},
          usedRoutes: {},
          random: Random(seed),
        )!;
        expect(next.at.isBefore(now.add(const Duration(minutes: 30))), isFalse);
        expect(next.at.isBefore(DateTime(2026, 10, 20, 19)), isTrue);
      }
      final late = FeatureTipRules.next(
        now: DateTime(2026, 10, 20, 18, 30),
        installedAt: installed,
        shown: {},
        usedRoutes: {},
        random: Random(3),
      )!;
      expect(late.at.day, 21);
    });

    test('skips features already used, none left: nothing', () {
      final next = FeatureTipRules.next(
        now: DateTime(2026, 10, 20, 9),
        installedAt: installed,
        shown: {},
        usedRoutes: {'offline-maps'},
        random: Random(1),
        tips: featureTips.take(2).toList(),
      );
      expect(next?.tip.id, 'home_widgets');
      expect(
        FeatureTipRules.next(
          now: DateTime(2026, 10, 20, 9),
          installedAt: installed,
          shown: {'home_widgets'},
          usedRoutes: {'offline-maps'},
          tips: featureTips.take(2).toList(),
        ),
        isNull,
      );
    });

    test('a week later across a clock change is a calendar week', () {
      // Europe moves its clocks on 25 Oct 2026.
      final next = FeatureTipRules.next(
        now: DateTime(2026, 10, 24, 8),
        installedAt: installed,
        lastTipAt: DateTime(2026, 10, 24, 12),
        shown: {},
        usedRoutes: {},
        random: Random(2),
      )!;
      expect(next.at.day, 31);
      expect(next.at.hour, inInclusiveRange(11, 18));
    });
  });

  group('feature tips', () {
    test('every tip opens a route a notification may open', () {
      for (final tip in featureTips) {
        if (tip.route case final route?) {
          expect(notificationLinkableRoutes, contains(route), reason: tip.id);
        }
        expect(tip.title.contains('!'), isFalse);
        expect(tip.body.length, lessThanOrEqualTo(90), reason: tip.id);
        expect(tip.iconAsset, startsWith('assets/icons/'));
      }
      expect(featureTips.map((t) => t.id).toSet().length, featureTips.length);
    });
  });

  group('FeatureTipsService', () {
    late _FakeScheduler scheduler;
    late SharedPreferences prefs;
    late DateTime now;

    Future<FeatureTipsService> service() async =>
        FeatureTipsService(prefs, scheduler, now: () => now, random: Random(4));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      scheduler = _FakeScheduler();
      now = DateTime(2026, 10, 1, 9);
    });

    test('plans one tip and keeps it across starts', () async {
      final tips = await service();
      await tips.reschedule();
      expect(scheduler.scheduled, hasLength(1));
      now = DateTime(2026, 10, 2, 9);
      await tips.reschedule();
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.cancels, 0);
    });

    test('once sent, the next waits a week and never repeats', () async {
      final tips = await service();
      await tips.reschedule();
      final (firstId, firstAt) = scheduler.scheduled.single;
      now = firstAt.add(const Duration(hours: 1));
      await tips.reschedule();
      expect(scheduler.scheduled, hasLength(2));
      final (secondId, secondAt) = scheduler.scheduled.last;
      expect(secondId, isNot(firstId));
      expect(
        secondAt.isBefore(
          DateTime(firstAt.year, firstAt.month, firstAt.day + 7),
        ),
        isFalse,
      );
      expect(prefs.getStringList(FeatureTipsService.shownKey), [firstId]);
    });

    test('opening the feature cancels its planned tip', () async {
      final tips = await service();
      await tips.reschedule();
      final planned = featureTips.firstWhere(
        (t) => t.id == scheduler.scheduled.single.$1,
      );
      if (planned.usedRoutes.isEmpty) return; // Shortcuts: nothing to open.
      tips.markUsed(planned.usedRoutes.first);
      await tips.reschedule();
      expect(scheduler.cancels, 1);
      expect(scheduler.scheduled.last.$1, isNot(planned.id));
    });

    test('off in Settings: cancelled, nothing planned', () async {
      final tips = await service();
      await tips.reschedule();
      await tips.setEnabled(false);
      expect(scheduler.cancels, 1);
      expect(tips.planned, isNull);
      await tips.reschedule();
      expect(scheduler.scheduled, hasLength(1));
    });

    test('notifications blocked: nothing planned', () async {
      scheduler.allowed = false;
      final tips = await service();
      await tips.reschedule();
      expect(scheduler.scheduled, isEmpty);
    });

    test('only routes a tip is about are recorded', () async {
      final tips = await service();
      tips.markUsed('dashboard');
      tips.markUsed('health-report');
      expect(tips.usedRoutes, {'health-report'});
    });

    test('in-app tips are answered once', () async {
      final tips = await service();
      expect(tips.isDismissed('offline_maps'), isFalse);
      await tips.dismiss('offline_maps');
      expect((await service()).isDismissed('offline_maps'), isTrue);
    });
  });

  group('FeatureTipCard', () {
    for (final scale in [1.0, kMaxTextScale]) {
      testWidgets('fits at text $scale', (tester) async {
        var acted = false;
        var dismissed = false;
        await pumpPage(
          tester,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: FeatureTipCard(
                icon: Icons.download_for_offline_rounded,
                title: 'Going somewhere without signal?',
                message:
                    'Save the map before you go. Workouts record anywhere.',
                actionLabel: 'Offline maps',
                onAction: () => acted = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
          textScale: scale,
          theme: scale == 1.0 ? null : AppTheme.darkTheme,
        );
        await tester.pump();
        expect(takeAllExceptions(tester), isEmpty);
        expect(truncatedTexts(tester), isEmpty);
        await tester.tap(find.text('Offline maps'));
        await tester.tap(find.text('Not now'));
        expect(acted && dismissed, isTrue);
      });
    }
  });
}
