import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/food_scanner/domain/ml_kit_errors.dart';

void main() {
  test('a model still downloading gets the getting-ready message', () {
    final e = Exception(
      'MlKitException: Waiting for the text optional module to be downloaded. '
      'Please wait.',
    );
    expect(mlKitErrorMessage(e, fallback: 'x'), kScannerGettingReady);
  });

  test('other failures keep the fallback', () {
    expect(
      mlKitErrorMessage(Exception('boom'), fallback: "Couldn't read the label."),
      "Couldn't read the label.",
    );
  });

  test('the message fits the 60 character style rule', () {
    expect(kScannerGettingReady.length, lessThanOrEqualTo(60));
  });
}
