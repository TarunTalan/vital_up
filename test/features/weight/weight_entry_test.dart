import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

void main() {
  test('kg range matches app-wide limits', () {
    expect(WeightUnit.kg.minValue, 20);
    expect(WeightUnit.kg.maxValue, 350);
    // Rounded inwards so a valid lbs entry never converts out of range.
    expect(WeightUnit.lbs.minValue, 45);
    expect(WeightUnit.lbs.maxValue, 771);
  });

  test('parses kg and comma decimals', () {
    expect(parseWeightEntry('72.4', WeightUnit.kg).kg, closeTo(72.4, 1e-9));
    expect(parseWeightEntry('72,4', WeightUnit.kg).kg, closeTo(72.4, 1e-9));
  });

  test('converts lbs to kg', () {
    expect(
      parseWeightEntry('154', WeightUnit.lbs).kg,
      closeTo(154 * kgPerLb, 1e-9),
    );
  });

  test('round trip keeps one decimal in lbs', () {
    final kg = parseWeightEntry('154.3', WeightUnit.lbs).kg!;
    expect(WeightUnit.lbs.format(kg), '154.3 lbs');
  });

  test('errors for empty and out-of-range input, in the chosen unit', () {
    expect(parseWeightEntry('', WeightUnit.kg).error, 'Enter your weight.');
    expect(parseWeightEntry('10', WeightUnit.kg).error, 'Enter 20 to 350 kg.');
    expect(
      parseWeightEntry('900', WeightUnit.lbs).error,
      'Enter 45 to 771 lbs.',
    );
    expect(parseWeightEntry('abc', WeightUnit.kg).kg, isNull);
  });
}
