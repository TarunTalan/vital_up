// In-app tips where they're placed: the sleep sheet's compact tip fits the
// sheet on a short phone at the largest text, and goes after "Got it".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/feature_tip_card.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';
import 'package:vital_up/features/feature_tips/data/feature_tips_service.dart';
import 'package:vital_up/features/feature_tips/domain/feature_tip.dart';
import 'package:vital_up/features/feature_tips/presentation/feature_tip_keys.dart';

import '../../helpers/pump_app.dart';

class _NoScheduler implements TipScheduler {
  @override
  Future<bool?> permitted() async => false;
  @override
  Future<void> schedule(FeatureTip tip, DateTime at) async {}
  @override
  Future<void> cancel() async {}
}

Widget _host(Widget sheet) => Builder(
  builder: (context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showAppBottomSheet<void>(context: context, builder: (_) => sheet),
    );
    return const Scaffold(body: SizedBox.expand());
  },
);

void main() {
  late FeatureTipsService tips;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tips = FeatureTipsService(
      await SharedPreferences.getInstance(),
      _NoScheduler(),
    );
    sl.registerSingleton<FeatureTipsService>(tips);
  });

  tearDown(() => sl.unregister<FeatureTipsService>());

  SleepLogSheet sheet() {
    final now = DateTime.now();
    return SleepLogSheet(
      goalMinutes: 8 * 60,
      initial: SleepSessionInfo(
        bedTime: DateTime(now.year, now.month, now.day - 1, 23, 15),
        wakeTime: DateTime(now.year, now.month, now.day, 6, 40),
        duration: const Duration(hours: 7, minutes: 25),
        source: SleepDataSource.manual,
      ),
    );
  }

  for (final (size, scale, dark) in [
    (const Size(360, 640), kMaxTextScale, false),
    (const Size(360, 800), 1.0, true),
    (const Size(412, 800), 1.3, false),
  ]) {
    testWidgets('sleep dial tip fits at ${size.width.round()}x'
        '${size.height.round()} text $scale', (tester) async {
      await tester.runAsync(loadAllFonts);
      await pumpPage(
        tester,
        _host(sheet()),
        textScale: scale,
        size: size,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTipCard), findsOneWidget);
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
      expect(shrunkTexts(tester), isEmpty);
    });
  }

  testWidgets('"Got it" hides the sleep tip for good', (tester) async {
    await pumpPage(tester, _host(sheet()), size: const Size(412, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureTipCard), findsNothing);
    expect(tips.isDismissed(FeatureTipKeys.sleepDial), isTrue);
  });

  testWidgets('answered before: no sleep tip', (tester) async {
    await tips.dismiss(FeatureTipKeys.sleepDial);
    await pumpPage(tester, _host(sheet()), size: const Size(412, 800));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureTipCard), findsNothing);
  });
}
