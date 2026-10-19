import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';

/// Sane ranges for one food entry. Values from the AI, food databases,
/// OCR or typing are clamped to these before they are shown or saved, so a
/// bad answer can never put NaN, negatives or absurd totals in the log.
abstract final class NutritionLimits {
  static const double caloriesMax = InputLimits.caloriesMax * 1.0;

  /// Calories in one whole meal log (server CHECK on `total_calories`).
  static const double mealCaloriesMax = 10000;

  /// Protein / carbs / fat / fibre / sugar grams in one entry.
  static const double macroGMax = 1000;

  /// Sodium, cholesterol and other milligram nutrients in one entry.
  static const double mgMax = 50000;

  /// Anything else (IU, mcg, additional nutrients).
  static const double otherMax = 100000;

  /// Portion quantity (in its own unit: grams, cups, pieces...).
  static const double quantityMin = 0.1;
  static const double quantityMax = InputLimits.gramsMax * 1.0;

  /// Scale factor allowed when a portion is changed in one step.
  static const double scaleMax = 1000;
}

/// Reads a number from untrusted JSON (num or numeric string) and returns it
/// clamped to [0, max]. Null, NaN, infinite or unparsable values give 0.
double saneAmount(Object? raw, {double max = NutritionLimits.otherMax}) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim().replaceAll(',', '.'));
  }
  if (value == null || !value.isFinite || value <= 0) return 0;
  return value > max ? max : value;
}

/// A portion quantity from untrusted input: finite and within
/// [NutritionLimits.quantityMin, NutritionLimits.quantityMax], else
/// [fallback].
double saneQuantity(Object? raw, {double fallback = 1}) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim().replaceAll(',', '.'));
  }
  if (value == null || !value.isFinite || value <= 0) return fallback;
  if (value < NutritionLimits.quantityMin) return NutritionLimits.quantityMin;
  if (value > NutritionLimits.quantityMax) return NutritionLimits.quantityMax;
  return value;
}

/// A 0..1 confidence score. Accepts percentages (e.g. 85) too.
double saneConfidence(Object? raw, {double fallback = 0}) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim());
  }
  if (value == null || !value.isFinite || value < 0) return fallback;
  if (value > 1 && value <= 100) value = value / 100;
  return value > 1 ? 1 : value;
}

/// A safe scale factor for changing a portion from [oldQuantity] to
/// [newQuantity]: 1 when either side is unusable.
double safeScale(double oldQuantity, double newQuantity) {
  if (!oldQuantity.isFinite || !newQuantity.isFinite || oldQuantity <= 0 || newQuantity <= 0) {
    return 1;
  }
  final factor = newQuantity / oldQuantity;
  if (!factor.isFinite || factor <= 0) return 1;
  return factor > NutritionLimits.scaleMax ? NutritionLimits.scaleMax : factor;
}

/// Food names coming back from the server or typed by the user: no control
/// characters, single line, at most [InputLimits.shortText] characters.
String saneFoodName(Object? raw, {String fallback = ''}) {
  final text = raw == null ? '' : sanitizeText(raw.toString(), maxLength: InputLimits.shortText);
  return text.isEmpty ? fallback : text;
}

/// A meal's calories: the sum of its foods, capped at what one meal log
/// may hold (the server refuses `meal_logs` rows above it, and a refused
/// row would stay on this phone only).
double mealTotalCalories(Iterable<NutritionInfo> foods) {
  final sum = foods.fold<double>(
    0,
    (total, n) => total + saneAmount(n.calories, max: NutritionLimits.caloriesMax),
  );
  return sum > NutritionLimits.mealCaloriesMax
      ? NutritionLimits.mealCaloriesMax
      : sum;
}

/// [info] with every value clamped to [NutritionLimits].
NutritionInfo sanitizeNutrition(NutritionInfo info) {
  double g(double v) => saneAmount(v, max: NutritionLimits.macroGMax);
  double mg(double v) => saneAmount(v, max: NutritionLimits.mgMax);
  double other(double v) => saneAmount(v);
  return NutritionInfo(
    calories: saneAmount(info.calories, max: NutritionLimits.caloriesMax),
    proteinG: g(info.proteinG),
    carbsG: g(info.carbsG),
    fatG: g(info.fatG),
    fiberG: g(info.fiberG),
    sugarG: g(info.sugarG),
    sodiumMg: mg(info.sodiumMg),
    calciumMg: mg(info.calciumMg),
    ironMg: mg(info.ironMg),
    vitaminAIu: other(info.vitaminAIu),
    vitaminCMg: mg(info.vitaminCMg),
    vitaminDIu: other(info.vitaminDIu),
    vitaminEMg: mg(info.vitaminEMg),
    vitaminKMg: mg(info.vitaminKMg),
    thiaminMg: mg(info.thiaminMg),
    riboflavinMg: mg(info.riboflavinMg),
    niacinMg: mg(info.niacinMg),
    vitaminB6Mg: mg(info.vitaminB6Mg),
    vitaminB12Mcg: other(info.vitaminB12Mcg),
    folateMcg: other(info.folateMcg),
    potassiumMg: mg(info.potassiumMg),
    phosphorusMg: mg(info.phosphorusMg),
    magnesiumMg: mg(info.magnesiumMg),
    zincMg: mg(info.zincMg),
    copperMg: mg(info.copperMg),
    manganeseMg: mg(info.manganeseMg),
    seleniumMcg: other(info.seleniumMcg),
    cholesterolMg: mg(info.cholesterolMg),
    saturatedFatG: g(info.saturatedFatG),
    transFatG: g(info.transFatG),
    monounsaturatedFatG: g(info.monounsaturatedFatG),
    polyunsaturatedFatG: g(info.polyunsaturatedFatG),
    additionalNutrients: [
      for (final n in info.additionalNutrients)
        AdditionalNutrient(
          id: n.id,
          name: saneFoodName(n.name),
          unit: sanitizeText(n.unit, maxLength: 10),
          value: other(n.value),
        ),
    ],
    per: sanitizeFoodItem(info.per),
  );
}

/// [item] with a clean name / unit / serving text and a usable quantity.
FoodItem sanitizeFoodItem(FoodItem item) {
  return FoodItem(
    id: item.id,
    name: saneFoodName(item.name, fallback: 'Food'),
    confidenceScore: saneConfidence(item.confidenceScore),
    servingDescription: sanitizeText(item.servingDescription, maxLength: InputLimits.shortText),
    quantity: saneQuantity(item.quantity),
    unit: _saneUnit(item.unit),
  );
}

String _saneUnit(String unit) {
  final clean = sanitizeText(unit, maxLength: 20);
  return clean.isEmpty ? 'serving' : clean;
}

/// Extracts a product code (GTIN / EAN / UPC, 6 to 14 digits) from a scanned
/// or typed value, including GS1 Digital Link QR codes
/// (`https://<any domain>/01/<GTIN>/...`). Null when the value is not a
/// product barcode (e.g. a website QR code).
String? normalizeProductBarcode(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.length > 2048) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return _digitalLinkGtin(value);
  }
  final digits = value.replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^\d{6,14}$').hasMatch(digits) ? digits : null;
}

/// The GTIN after the `01` (or legacy `gtin`) key of a GS1 Digital Link URL,
/// when its check digit is right. A zero-padded GTIN-14 becomes the 13 digits
/// printed under the same package's EAN barcode, so both scans find one product.
String? _digitalLinkGtin(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  final segments = uri.pathSegments;
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] != '01' && segments[i].toLowerCase() != 'gtin') continue;
    var gtin = segments[i + 1];
    if (!RegExp(r'^(\d{8}|\d{12,14})$').hasMatch(gtin) || !isValidGtin(gtin)) {
      return null;
    }
    if (gtin.length == 14 && gtin.startsWith('0')) gtin = gtin.substring(1);
    return gtin;
  }
  return null;
}

/// Whether [code] (GTIN-8, -12, -13 or -14) ends with the right GS1 check digit.
bool isValidGtin(String code) {
  if (!RegExp(r'^\d{8,14}$').hasMatch(code)) return false;
  final digits = code.codeUnits.map((c) => c - 48).toList();
  var sum = 0;
  // Weights 3, 1, 3... from the digit left of the check digit.
  for (var i = digits.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += digits[i] * weight;
  }
  return (10 - sum % 10) % 10 == digits.last;
}

/// Splits a serving text such as "1 bowl (150g)", "2 pieces", "100 g" or
/// "250ml" into a quantity and one of the app's units. Grams win when the
/// text gives them. Falls back to 100 g.
({double quantity, String unit}) parseServingSize(String serving) {
  final text = serving.toLowerCase();
  final grams = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:g|gm|gms|grams?|ml)\b').firstMatch(text);
  if (grams != null) {
    final value = saneQuantity(grams.group(1), fallback: 100);
    return (quantity: value, unit: 'g');
  }
  final count = RegExp(r'^\s*(\d+(?:[.,]\d+)?)').firstMatch(text);
  final amount = count == null ? null : saneQuantity(count.group(1), fallback: 1);
  if (text.contains('piece') || RegExp(r'\bpcs?\b').hasMatch(text)) {
    return (quantity: amount ?? 1, unit: 'piece');
  }
  if (text.contains('slice')) return (quantity: amount ?? 1, unit: 'slice');
  if (text.contains('cup')) return (quantity: amount ?? 1, unit: 'cup');
  if (text.contains('tbsp')) return (quantity: amount ?? 1, unit: 'tbsp');
  if (text.contains('tsp')) return (quantity: amount ?? 1, unit: 'tsp');
  if (amount != null) return (quantity: amount, unit: 'serving');
  return (quantity: 100, unit: 'g');
}
