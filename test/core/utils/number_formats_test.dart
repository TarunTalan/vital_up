import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/number_formats.dart';

void main() {
  test('counts are whole and grouped', () {
    expect(formatCount(9850.4), '9,850');
    expect(formatCount(0), '0');
  });

  test('compact counts stay exact below 10,000 and shorten above', () {
    expect(formatCompactCount(9999), '9,999');
    expect(formatCompactCount(10000), '10K');
    expect(formatCompactCount(12500), '12.5K');
    expect(formatCompactCount(1200000), '1.2M');
  });
}
