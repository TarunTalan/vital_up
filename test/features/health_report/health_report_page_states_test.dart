import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/health_report/data/services/health_report_service.dart';
import 'package:vital_up/features/health_report/presentation/pages/health_report_page.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

import '../../helpers/pump_app.dart';

const _summary = HealthReportSummary(
  daysCount: 30,
  avgSleepHours: 7.2,
  avgSleepScore: 82,
  nightsLogged: 24,
  totalWorkouts: 12,
  totalActiveMinutes: 1340,
  totalDistanceKm: 48.6,
  avgWaterMl: 1850,
  waterDaysLogged: 27,
  latestWeightKg: 72.4,
  bloodPressure: '120/80',
  restingBpm: 64,
);

class _FakeReport implements HealthReportService {
  final bool fail;
  _FakeReport({this.fail = false});

  @override
  Future<HealthReportSummary> generateSummary({int days = 30}) async {
    if (fail) throw Exception('offline');
    return _summary;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWeight implements WeightService {
  @override
  Future<WeightUnit> unit() async => WeightUnit.kg;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  bool fail = false,
  double textScale = 1,
}) async {
  await sl.reset();
  sl.registerSingleton<HealthReportService>(_FakeReport(fail: fail));
  sl.registerSingleton<WeightService>(_FakeWeight());
  addTearDown(sl.reset);
  await pumpPage(tester, const HealthReportPage(), textScale: textScale);
  await settle(tester);
}

void main() {
  testWidgets('loaded: every area with its figures and the share button', (
    tester,
  ) async {
    await _pump(tester);
    for (final title in ['Body and heart', 'Sleep', 'Activity', 'Hydration']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Resting pulse'), findsOneWidget);
    expect(find.text('Share with doctor'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
  });

  testWidgets('error: retry, no share button', (tester) async {
    await _pump(tester, fail: true);
    expect(find.text('Share with doctor'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  for (final scale in [1.0, kMaxTextScale]) {
    testWidgets('fits a small phone, whole text, at $scale text', (
      tester,
    ) async {
      await _pump(tester, textScale: scale);
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }
}
