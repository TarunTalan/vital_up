import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vital_up/core/services/app_loading_controller.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// A small phone (360x690 dp), the narrowest layout the app supports.
const Size kSmallPhone = Size(360, 690);

/// Largest system text size the app honours (`ResponsiveTextScale`).
const double kMaxTextScale = ResponsiveTextScale.maxSystemScale;

bool _fontsLoaded = false;

/// Loads the real Nunito files so text measures like on a phone. The test
/// font draws every glyph a full em wide, which would report overflows
/// that never happen with the shipped font.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  GoogleFonts.config.allowRuntimeFetching = false;
  final nunito = FontLoader('Nunito');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    nunito.addFont(rootBundle.load('assets/fonts/Nunito-$w.ttf'));
  }
  await nunito.load();
  _fontsLoaded = true;
}

/// Pumps [page] the way the app shows it: app theme, system text size
/// through [ResponsiveTextScale], on a [size] screen.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  double textScale = 1.0,
  Size size = kSmallPhone,
  ThemeData? theme,
}) async {
  await tester.runAsync(loadAppFonts);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    // Loader pages arm the barrier's 30 s watchdog.
    AppLoadingController.instance.reset();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      builder: (context, child) => ResponsiveTextScale(child: child!),
      home: page,
    ),
  );
}

/// Lets futures finish while [VitalUpLoader] keeps animating (so
/// `pumpAndSettle` would never return).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every exception thrown while laying out the page, e.g. a RenderFlex
/// overflow. Empty when the page fits.
List<Object> takeAllExceptions(WidgetTester tester) {
  final errors = <Object>[];
  for (
    Object? e = tester.takeException();
    e != null;
    e = tester.takeException()
  ) {
    errors.add(e);
  }
  return errors;
}

/// The text scale [finder]'s widget is laid out with.
double shownTextScale(WidgetTester tester, Finder finder) =>
    MediaQuery.textScalerOf(tester.element(finder)).scale(10) / 10;
