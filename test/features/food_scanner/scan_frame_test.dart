import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/food_scanner/presentation/utils/scan_frame.dart';

PlacedCode _code(String value, Offset centre) => (
      value: value,
      points: [
        centre + const Offset(-20, -10),
        centre + const Offset(20, -10),
        centre + const Offset(20, 10),
        centre + const Offset(-20, 10),
      ],
    );

void main() {
  const screen = Size(412, 900);
  final frame = scanFrameRect(screen);

  test('scanFrameRect keeps the gutter and lifts the frame', () {
    expect(frame.left, 16);
    expect(frame.width, 380);
    expect(frame.height, closeTo(315, 0.001));
    expect(frame.top, closeTo((900 - 315) / 2 - 40, 0.001));
  });

  group('mapCameraPoint', () {
    test('maps an upright point onto the cover-fitted preview', () {
      // 1280 x 720 sensor frame, rotated 90: upright 720 x 1280.
      const image = Size(1280, 720);
      const phone = Size(360, 800);
      // Centre stays the centre.
      expect(mapCameraPoint(const Offset(360, 640), image, 90, phone), const Offset(180, 400));
      // Scale 0.625, 45 px cropped off each side.
      expect(mapCameraPoint(Offset.zero, image, 90, phone), const Offset(-45, 0));
      expect(mapCameraPoint(Offset.zero, image, 270, phone), const Offset(-45, 0));
    });

    test('does not swap sides for an unrotated sensor', () {
      expect(mapCameraPoint(const Offset(100, 50), const Size(400, 200), 0, const Size(400, 200)), const Offset(100, 50));
    });
  });

  group('pickCodeInFrame', () {
    final inside = frame.center;
    final outside = Offset(frame.center.dx, frame.bottom + 100);

    test('prefers the product barcode over a website QR', () {
      final picked = pickCodeInFrame([
        _code('https://brand.example/offers', inside),
        _code('8901058851427', inside + const Offset(0, 40)),
      ], frame);
      expect(picked?.product, '8901058851427');
      expect(picked?.code.value, '8901058851427');
    });

    test('ignores codes outside the frame', () {
      expect(pickCodeInFrame([_code('8901058851427', outside)], frame), isNull);
      final picked = pickCodeInFrame([
        _code('8901058851427', outside),
        _code('https://brand.example/offers', inside),
      ], frame);
      expect(picked?.product, isNull);
      expect(picked?.code.value, 'https://brand.example/offers');
    });

    test('reads Digital Link QR codes in the frame', () {
      final picked = pickCodeInFrame([_code('https://id.gs1.org/01/09506000134352', inside)], frame);
      expect(picked?.product, '9506000134352');
    });

    test('skips codes without corners and returns null for none', () {
      expect(pickCodeInFrame([(value: '8901058851427', points: <Offset>[])], frame), isNull);
      expect(pickCodeInFrame([], frame), isNull);
    });
  });
}
