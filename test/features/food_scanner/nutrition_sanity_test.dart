import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/food_scanner/data/models/food_item_dto.dart';
import 'package:vital_up/features/food_scanner/data/models/nutrition_response_parser.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/nutrition_ocr_parser.dart';

const _item = FoodItem(
  id: '1',
  name: 'Dal',
  confidenceScore: 1,
  servingDescription: '1 bowl',
  quantity: 1,
  unit: 'serving',
);

void main() {
  group('saneAmount', () {
    test('reads numbers and numeric strings', () {
      expect(saneAmount(12.5), 12.5);
      expect(saneAmount('12,5'), 12.5);
      expect(saneAmount(' 7 '), 7);
    });

    test('negative, NaN, infinite and junk become 0', () {
      expect(saneAmount(-3), 0);
      expect(saneAmount(double.nan), 0);
      expect(saneAmount(double.infinity), 0);
      expect(saneAmount('abc'), 0);
      expect(saneAmount(null), 0);
      expect(saneAmount(<String>[]), 0);
    });

    test('clamps to the max', () {
      expect(saneAmount(99999, max: NutritionLimits.caloriesMax), NutritionLimits.caloriesMax);
    });
  });

  test('saneQuantity rejects zero / negative and clamps huge values', () {
    expect(saneQuantity(0), 1);
    expect(saneQuantity(-2, fallback: 5), 5);
    expect(saneQuantity(double.nan), 1);
    expect(saneQuantity(0.01), NutritionLimits.quantityMin);
    expect(saneQuantity(1e9), NutritionLimits.quantityMax);
    expect(saneQuantity('150'), 150);
  });

  test('saneConfidence keeps 0..1 and reads percentages', () {
    expect(saneConfidence(0.8), 0.8);
    expect(saneConfidence(85), 0.85);
    expect(saneConfidence(500), 1);
    expect(saneConfidence(-1), 0);
  });

  test('safeScale never divides by zero', () {
    expect(safeScale(0, 100), 1);
    expect(safeScale(100, 0), 1);
    expect(safeScale(100, 250), 2.5);
    expect(safeScale(0.0001, 5000), NutritionLimits.scaleMax);
  });

  group('normalizeProductBarcode', () {
    test('accepts EAN / UPC codes', () {
      expect(normalizeProductBarcode('8901058851427'), '8901058851427');
      expect(normalizeProductBarcode(' 12345670 '), '12345670');
    });

    test('reads GS1 Digital Link URLs', () {
      expect(normalizeProductBarcode('https://id.gs1.org/01/09506000134352'), '09506000134352');
    });

    test('rejects plain QR content', () {
      expect(normalizeProductBarcode('https://example.com/menu'), isNull);
      expect(normalizeProductBarcode('hello world'), isNull);
      expect(normalizeProductBarcode('12'), isNull);
      expect(normalizeProductBarcode(''), isNull);
    });
  });

  group('parseServingSize', () {
    test('prefers grams in the text', () {
      final s = parseServingSize('1 bowl (150g)');
      expect(s.quantity, 150);
      expect(s.unit, 'g');
    });

    test('reads counts and units', () {
      expect(parseServingSize('2 pieces').unit, 'piece');
      expect(parseServingSize('2 pieces').quantity, 2);
      expect(parseServingSize('1 cup').unit, 'cup');
      expect(parseServingSize('1 serving').unit, 'serving');
    });

    test('falls back to 100 g', () {
      final s = parseServingSize('');
      expect(s.quantity, 100);
      expect(s.unit, 'g');
    });
  });

  test('parseNutritionResponse clamps malformed AI values', () {
    final info = parseNutritionResponse({
      'calories': -50,
      'protein_g': '12.5',
      'carbs_g': 1e12,
      'fat_g': 'NaN',
      'additional_nutrients': ['bad', {'name': 'Iron', 'unit': 'mg', 'value': -1}],
    }, _item);
    expect(info.calories, 0);
    expect(info.proteinG, 12.5);
    expect(info.carbsG, NutritionLimits.macroGMax);
    expect(info.fatG, 0);
    expect(info.additionalNutrients.single.value, 0);
  });

  test('FoodItemDto.fromJson tolerates numeric ids and bad numbers', () {
    final dto = FoodItemDto.fromJson({
      'id': 42,
      'name': '  Paneer\ntikka ',
      'confidence_score': 90,
      'quantity': 0,
    });
    expect(dto.id, '42');
    expect(dto.name, 'Paneer tikka');
    expect(dto.confidenceScore, 0.9);
    expect(dto.quantity, 1);
    expect(dto.unit, 'serving');
  });

  group('NutritionOcrParser', () {
    test('sodium in mg is not multiplied by 1000', () {
      final v = NutritionOcrParser.parseNutritionText('Sodium 450mg');
      expect(v['sodium'], 450);
    });

    test('reads "fibre" and comma decimals', () {
      final v = NutritionOcrParser.parseNutritionText('Dietary Fibre 2,5 g');
      expect(v['fiber'], 2.5);
    });
  });
}
