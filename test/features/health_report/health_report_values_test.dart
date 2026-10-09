import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/health_report/data/services/health_report_service.dart';

void main() {
  test('missing values say so instead of inventing typical ones', () {
    expect(reportValue(null, (v) => '$v'), notRecorded);
    expect(reportValue(68, (v) => '$v bpm'), '68 bpm');
  });

  test('blood pressure needs two plausible numbers', () {
    expect(reportBloodPressure('120', '80'), '120/80');
    expect(reportBloodPressure('', '80'), isNull);
    expect(reportBloodPressure('80', '120'), isNull);
    expect(reportBloodPressure('abc', '80'), isNull);
  });

  test('resting heart rate must be plausible', () {
    expect(reportRestingBpm('68'), 68);
    expect(reportRestingBpm(''), isNull);
    expect(reportRestingBpm('0'), isNull);
  });

  test('water averages over days with water, not the whole period', () {
    expect(averageDailyWater({}), isNull);
    expect(
      averageDailyWater({
        DateTime(2026, 1, 1): 2000,
        DateTime(2026, 1, 2): 1000,
      }),
      1500,
    );
  });
}
