import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/about/presentation/pages/about_page.dart';

void main() {
  test('feedback must have text', () {
    expect(validateFeedback(''), isNotNull);
    expect(validateFeedback('  \n '), isNotNull);
    expect(validateFeedback('Love it'), isNull);
  });

  test('feedback is cleaned and capped', () {
    expect(cleanFeedback('  Great   app  '), 'Great app');
    expect(cleanFeedback('x' * 900).length, InputLimits.note);
  });
}
