import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';

import '../../helpers/pump_app.dart';

/// The Scan tab's camera card sits along the bottom edge like the other
/// permission cards, over the dark camera area, and fits at any text size.
/// `HOME_SHOTS=1` writes build/permission_shots/scan_*.png.
void main() {
  for (final c in const [
    (width: 360.0, height: 640.0, scale: kMaxTextScale, dark: false),
    (width: 412.0, height: 915.0, scale: 1.0, dark: false),
    (width: 412.0, height: 915.0, scale: 1.0, dark: true),
  ]) {
    final id =
        'scan_${c.width.round()}_${c.scale}_${c.dark ? 'dark' : 'light'}';
    testWidgets(id, (tester) async {
      await tester.runAsync(loadAllFonts);
      var gallery = 0;
      await pumpPage(
        tester,
        Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.cameraBackdrop),
            ),
            Positioned.fill(
              child: CameraPermissionSheet(
                blocked: false,
                onAllow: () {},
                onGallery: () => gallery++,
              ),
            ),
          ],
        ),
        textScale: c.scale,
        size: Size(c.width, c.height),
        theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      await tester.pumpAndSettle();

      // Along the bottom edge, not floating near the top: its last button
      // ends just above the bottom (scrolled to, on a small phone at the
      // largest text, where the card is taller than the screen).
      await tester.ensureVisible(find.text('Pick from gallery'));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.text('Pick from gallery'));
      expect(c.height - last.bottom, lessThan(AppDimens.sectionGap * 2));

      await tester.tap(find.text('Pick from gallery'));
      expect(gallery, 1);

      if (Platform.environment['HOME_SHOTS'] == '1') {
        await tester.runAsync(() async {
          final view = tester.binding.renderViews.first;
          final layer = view.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & view.size,
            pixelRatio: 1,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File('build/permission_shots/$id.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }
}
