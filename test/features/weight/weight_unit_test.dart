import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

void main() {
  test('converts between kg and lbs both ways', () {
    expect(WeightUnit.lbs.fromKg(100), closeTo(220.46, 0.01));
    expect(WeightUnit.lbs.toKg(220.462), closeTo(100, 0.01));
    expect(WeightUnit.kg.fromKg(72.4), 72.4);
  });

  test('formats in the chosen unit', () {
    expect(WeightUnit.kg.format(72.44), '72.4 kg');
    expect(WeightUnit.lbs.format(50), '110.2 lbs');
  });

  test('unknown setting falls back to kg', () {
    expect(WeightUnit.fromCode(null), WeightUnit.kg);
    expect(WeightUnit.fromCode('lbs'), WeightUnit.lbs);
    // Onboarding stores pounds as 'lb'.
    expect(WeightUnit.fromCode('lb'), WeightUnit.lbs);
  });
}
