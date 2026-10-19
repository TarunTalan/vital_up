import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';

import '../../helpers/pump_app.dart';

Future<void> _pump(WidgetTester tester, double textScale) => pumpPage(
  tester,
  Scaffold(
    body: Padding(
      // A bottom sheet's gutters on a small phone.
      padding: const EdgeInsets.all(20),
      child: AppSegmentedControl<String>(
        values: smokerOptions,
        selected: 'No',
        label: (v) => v,
        onChanged: (_) {},
      ),
    ),
  ),
  textScale: textScale,
);

/// Lines the label [text] is drawn on.
int _lines(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      )
      .map((b) => b.top)
      .toSet()
      .length;
}

void main() {
  for (final scale in [1.0, 1.15, kMaxTextScale]) {
    testWidgets('lifestyle options stay on one line at $scale text', (
      tester,
    ) async {
      await _pump(tester, scale);
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
      for (final option in smokerOptions) {
        expect(_lines(tester, option), 1, reason: option);
      }
    });
  }

  testWidgets('a long label gets more room than short ones', (tester) async {
    await _pump(tester, 1);
    final long = tester.getSize(find.text('Occasionally')).width;
    final short = tester.getSize(find.text('No')).width;
    expect(long, greaterThan(short));
  });
}
