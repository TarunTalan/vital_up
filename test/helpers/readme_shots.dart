// Phone-sized screenshots for the README. Each screen test that has one
// adds a `readme:` case, skipped unless README_SHOTS is set:
//
//   README_SHOTS=1 flutter test test/features/dashboard/home_cards_screenshot_test.dart
//
// PNGs land in docs/screenshots/ (412 x 892 dp at 2x). The demo user is
// Tarun Talan (@tarun_talan).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_bottom_nav.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

import 'pump_app.dart';

/// README screenshots are written only when this is set (`README_SHOTS=1`).
final bool readmeShots = Platform.environment['README_SHOTS'] == '1';

/// A common Android phone (Pixel 7 class), in dp.
const Size kReadmePhone = Size(412, 892);

const String kDemoName = 'Tarun Talan';
const String kDemoUsername = 'tarun_talan';

/// The dashboard's floating nav bar with [index] selected (mirrors
/// `_DashboardPageState._items`).
Widget readmeNavBar(int index) => AppBottomNav(
  items: const [
    AppBottomNavItem('Home', 'assets/icons/nav/home.svg'),
    AppBottomNavItem('Scan', 'assets/icons/nav/scanner.svg'),
    AppBottomNavItem('Vita', 'assets/icons/nav/vita.svg'),
    AppBottomNavItem('Arena', GamificationIcons.community),
    AppBottomNavItem('Profile', 'assets/icons/nav/profile.svg'),
  ],
  selectedIndex: index,
  onItemSelected: (_) {},
);

/// Pumps [page] on a phone screen with every font loaded.
Future<void> pumpReadmePage(
  WidgetTester tester,
  Widget page, {
  bool dark = false,
}) async {
  await tester.runAsync(loadAllFonts);
  await pumpPage(
    tester,
    page,
    size: kReadmePhone,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  );
  await settleReadmeAssets(tester);
}

/// Lets asset loads (background image, SVG and WebP icons) finish and
/// progress animations run to the end.
Future<void> settleReadmeAssets(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(seconds: 2));
}

/// Writes the whole screen to `docs/screenshots/<name>.png`.
Future<void> captureReadmeShot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('docs/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
