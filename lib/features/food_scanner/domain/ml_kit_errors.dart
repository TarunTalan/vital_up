/// ML Kit runs through Google Play Services, which downloads the OCR and
/// barcode models after install. Until they arrive, ML Kit fails with an
/// "UNAVAILABLE" / "waiting for the model to be downloaded" error.
bool isMlKitModelPending(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('waiting for') && text.contains('download') ||
      text.contains('model') && text.contains('unavailable');
}

const kScannerGettingReady = 'Scanner is getting ready. Try again in a minute.';

/// The message for an ML Kit failure: the model download, or [fallback].
String mlKitErrorMessage(Object error, {required String fallback}) =>
    isMlKitModelPending(error) ? kScannerGettingReady : fallback;
