import 'package:logger/logger.dart';

class NutritionOcrParser {
  static final Logger _logger = Logger();

  /// Parses OCR-recognized text to find core nutrition values.
  /// Standard Indian labels list nutrition per 100g or per serving.
  static Map<String, double> parseNutritionText(String text) {
    final Map<String, double> values = {
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'sodium': 0.0,
    };

    final lines = text.split('\n');
    final numberRegExp = RegExp(r'(\d+(?:\.\d+)?)');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lowerLine = line.toLowerCase();
      if (line.isEmpty) continue;

      // Helper to find a number in current line or subsequent line (lookahead)
      double? findNumber(int currentIndex) {
        // Try current line
        var match = numberRegExp.firstMatch(lines[currentIndex]);
        if (match != null) {
          return double.tryParse(match.group(1)!);
        }
        // Try next line (lookahead) if current line has no number
        if (currentIndex + 1 < lines.length) {
          final nextLine = lines[currentIndex + 1].trim();
          match = numberRegExp.firstMatch(nextLine);
          if (match != null) {
            // Ensure next line is just a number/unit, not another nutrient name
            final isNutrient = nextLine.toLowerCase().contains(RegExp(
                r'energy|calor|protein|carb|fat|sugar|fiber|sodium|salt'));
            if (!isNutrient) {
              return double.tryParse(match.group(1)!);
            }
          }
        }
        return null;
      }

      // 1. Calories / Energy
      if ((lowerLine.contains('energy') ||
              lowerLine.contains('calor') ||
              lowerLine.contains('kcal')) &&
          !lowerLine.contains('from fat')) {
        final val = findNumber(i);
        if (val != null && values['calories'] == 0.0) {
          if (lowerLine.contains('kj') || lowerLine.contains('kjoules')) {
            values['calories'] = val / 4.184; // convert kJ to kcal
          } else {
            values['calories'] = val;
          }
          _logger.d('OCR Parsed Calories: ${values['calories']}');
        }
      }
      // 2. Protein
      else if (lowerLine.contains('protein')) {
        final val = findNumber(i);
        if (val != null && values['protein'] == 0.0) {
          values['protein'] = val;
          _logger.d('OCR Parsed Protein: ${values['protein']}');
        }
      }
      // 3. Carbohydrates
      else if (lowerLine.contains('carbohydrate') || lowerLine.contains('carbs')) {
        final val = findNumber(i);
        if (val != null && values['carbs'] == 0.0) {
          values['carbs'] = val;
          _logger.d('OCR Parsed Carbs: ${values['carbs']}');
        }
      }
      // 4. Fat (excluding saturated and trans fat)
      else if (lowerLine.contains('fat') &&
          !lowerLine.contains('saturated') &&
          !lowerLine.contains('trans') &&
          !lowerLine.contains('mono') &&
          !lowerLine.contains('poly')) {
        final val = findNumber(i);
        if (val != null && values['fat'] == 0.0) {
          values['fat'] = val;
          _logger.d('OCR Parsed Fat: ${values['fat']}');
        }
      }
      // 5. Sugar
      else if (lowerLine.contains('sugar')) {
        final val = findNumber(i);
        if (val != null && values['sugar'] == 0.0) {
          values['sugar'] = val;
          _logger.d('OCR Parsed Sugar: ${values['sugar']}');
        }
      }
      // 6. Fiber
      else if (lowerLine.contains('fiber')) {
        final val = findNumber(i);
        if (val != null && values['fiber'] == 0.0) {
          values['fiber'] = val;
          _logger.d('OCR Parsed Fiber: ${values['fiber']}');
        }
      }
      // 7. Sodium / Salt
      else if (lowerLine.contains('sodium') || lowerLine.contains('salt')) {
        final val = findNumber(i);
        if (val != null && values['sodium'] == 0.0) {
          if (lowerLine.contains('salt')) {
            // Salt to Sodium conversion: Sodium (mg) = Salt (g) * 1000 / 2.5
            values['sodium'] = (val * 1000.0) / 2.5;
          } else {
            // If sodium is explicitly labeled in grams
            if (lowerLine.contains(' g') || lowerLine.endsWith('g')) {
              values['sodium'] = val * 1000.0;
            } else {
              values['sodium'] = val; // default is mg
            }
          }
          _logger.d('OCR Parsed Sodium: ${values['sodium']} mg');
        }
      }
    }

    return values;
  }
}
