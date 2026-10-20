import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vital_up/core/services/app_loading_controller.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

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

/// Texts on screen that don't show whole: cut by an ellipsis or a lost
/// line, or clipped by a box shorter than the text. Empty when every text
/// is complete. Text inside scroll views that sit off screen counts too.
/// [previews] are free texts (names, messages) meant to be cut short.
List<String> truncatedTexts(
  WidgetTester tester, {
  Set<String> previews = const {},
}) {
  final cut = <String>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph && node.hasSize) {
      final plain = node.text.toPlainText();
      final text = plain.replaceAll('\n', ' / ');
      final width = node.size.width;
      final fullHeight = node.getMinIntrinsicHeight(width);
      if (previews.contains(plain)) {
        // Free text shown as a preview (full text a tap away).
      } else if (node.didExceedMaxLines) {
        cut.add('"$text" (cut off)');
      } else if (fullHeight > node.size.height + 0.5) {
        cut.add('"$text" (clipped height)');
      } else if (node.maxLines == 1 &&
          node.getMaxIntrinsicWidth(double.infinity) > width + 0.5) {
        cut.add('"$text" (too wide)');
      }
    }
    node.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return cut;
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

/// Texts [FitText] drew smaller than their style to fit: on Home every
/// figure and label should show at its own size, so two tiles side by side
/// never end up with different-sized figures.
List<String> shrunkTexts(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph && node.hasSize) {
      final scaler = node.textScaler;
      if (scaler is ShrunkTextScaler && scaler.factor < 0.995) {
        out.add(
          '"${node.text.toPlainText()}" at '
          '${(scaler.factor * 100).round()}%',
        );
      }
    }
    node.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return out;
}

bool _iconFontsLoaded = false;

/// Loads every font in the test bundle's FontManifest (Material Icons
/// above all: without it icons draw as empty boxes).
Future<void> loadAllFonts() async {
  await loadAppFonts();
  if (_iconFontsLoaded) return;
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    if (family == 'Nunito') continue;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  _iconFontsLoaded = true;
}
