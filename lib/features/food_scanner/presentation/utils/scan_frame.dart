import 'dart:math' as math;
import 'dart:ui';

import 'package:vital_up/core/theme/app_dimens.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';

/// Scan-frame geometry, shared by the overlay painter, the captured preview
/// card, the photo crop and the barcode frame check so they always agree.
const double kScanFrameInset = AppDimens.gutter;
const double kScanFrameHeightFraction = 0.35;
const double kScanFrameLift = AppDimens.space40;

/// The scan frame inside a full-screen camera view of [screen].
Rect scanFrameRect(Size screen) {
  final height = screen.height * kScanFrameHeightFraction;
  return Rect.fromLTWH(
    kScanFrameInset,
    (screen.height - height) / 2 - kScanFrameLift,
    screen.width - 2 * kScanFrameInset,
    height,
  );
}

/// Maps a point ML Kit found in a camera frame of [imageSize] (as the sensor
/// delivers it) to the full-screen, cover-fitted preview. ML Kit reports
/// points in the upright image (after the rotation it was given), so only
/// the scale and the cover crop apply.
Offset mapCameraPoint(
  Offset point,
  Size imageSize,
  int sensorOrientation,
  Size screen,
) {
  final sideways = sensorOrientation % 180 == 90;
  final previewW = sideways ? imageSize.height : imageSize.width;
  final previewH = sideways ? imageSize.width : imageSize.height;
  final scale = math.max(screen.width / previewW, screen.height / previewH);
  final dx = (screen.width - previewW * scale) / 2;
  final dy = (screen.height - previewH * scale) / 2;
  return Offset(point.dx * scale + dx, point.dy * scale + dy);
}

/// A scanned value and its corners on screen.
typedef PlacedCode = ({String value, List<Offset> points});

/// The code to act on among those in view: the first product code whose
/// centre is inside [frame], else the first other code there (for the "not
/// a food barcode" hint) with a null `product`. Codes outside the frame, such
/// as one at the edge of the picture, are ignored: null when none is inside.
({PlacedCode code, String? product})? pickCodeInFrame(
  List<PlacedCode> codes,
  Rect frame,
) {
  ({PlacedCode code, String? product})? other;
  for (final code in codes) {
    if (code.points.isEmpty || !frame.contains(_centre(code.points))) continue;
    final product = normalizeProductBarcode(code.value);
    if (product != null) return (code: code, product: product);
    other ??= (code: code, product: null);
  }
  return other;
}

Offset _centre(List<Offset> points) {
  var sum = Offset.zero;
  for (final p in points) {
    sum += p;
  }
  return sum / points.length.toDouble();
}
