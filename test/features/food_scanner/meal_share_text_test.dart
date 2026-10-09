import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/food_scan_utils.dart';

void main() {
  group('FoodScanUtils.shareText', () {
    test('lists dishes, calories and macros', () {
      final text = FoodScanUtils.shareText(
        mealLabel: 'Lunch',
        dishNames: ['Dal tadka', 'Rice'],
        calories: 620,
        macros: [('Protein', 22), ('Carbs', 90), ('Fat', 18)],
      );
      expect(
        text,
        'Lunch: Dal tadka, Rice\n'
        '620 kcal · Protein 22 g · Carbs 90 g · Fat 18 g\n'
        'Tracked with VitalUp',
      );
    });

    test('skips blank names and zero macros', () {
      final text = FoodScanUtils.shareText(
        mealLabel: 'Snack',
        dishNames: ['  ', 'Apple '],
        calories: 95,
        macros: [('Protein', 0), ('Carbs', 25)],
      );
      expect(text, 'Snack: Apple\n95 kcal · Carbs 25 g\nTracked with VitalUp');
    });

    test('falls back to the meal label and never shows negative calories', () {
      final text = FoodScanUtils.shareText(
        mealLabel: 'Dinner',
        dishNames: const [],
        calories: -5,
      );
      expect(text, 'Dinner\n0 kcal\nTracked with VitalUp');
    });
  });
}
