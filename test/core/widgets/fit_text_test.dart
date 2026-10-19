import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_text_styles.dart';
import 'package:vital_up/core/widgets/fit_text.dart';

const _style = TextStyle(fontSize: 20);

Future<Text> _pump(
  WidgetTester tester,
  String text, {
  required double width,
  double textScale = 1,
  Widget Function(String)? build,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            child: build?.call(text) ?? FitText(text, style: _style),
          ),
        ),
      ),
    ),
  );
  return tester.widget<Text>(find.byType(Text));
}

double _shownSize(Text text) => text.textScaler!.scale(_style.fontSize!);

void main() {
  test('the floor is 75% of the size, never below the minimum', () {
    expect(FitText.minFontSizeFor(36), 27);
    expect(FitText.minFontSizeFor(14), AppTextStyles.minFontSize);
    expect(FitText.minFontSizeFor(12), 12);
    expect(FitText.minFontSizeFor(10), 10);
  });

  testWidgets('text that fits keeps its size', (tester) async {
    final text = await _pump(tester, 'Hi', width: 300);
    expect(_shownSize(text), 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a little too long shrinks, staying above the floor', (
    tester,
  ) async {
    // 20 characters of the 20px test font is 400px wide; 360 needs ~18px.
    final text = await _pump(tester, 'a' * 20, width: 360);
    final size = _shownSize(text);
    expect(size, lessThan(20));
    expect(size, greaterThanOrEqualTo(FitText.minFontSizeFor(20)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('far too long stops at the floor and ends in an ellipsis', (
    tester,
  ) async {
    final text = await _pump(tester, 'a' * 60, width: 200);
    expect(_shownSize(text), closeTo(FitText.minFontSizeFor(20), 0.01));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floor follows the system text size', (tester) async {
    final text = await _pump(tester, 'a' * 60, width: 200, textScale: 0.8);
    expect(_shownSize(text), closeTo(FitText.minFontSizeFor(20) * 0.8, 0.01));
  });

  testWidgets('rich text never takes its smallest span below the minimum', (
    tester,
  ) async {
    final text = await _pump(
      tester,
      'a' * 40,
      width: 150,
      build: (s) => FitText.rich(
        TextSpan(
          children: [
            TextSpan(text: s, style: const TextStyle(fontSize: 36)),
            const TextSpan(text: ' / 2 L', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
    expect(
      text.textScaler!.scale(14),
      greaterThanOrEqualTo(AppTextStyles.minFontSize - 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('works where the parent asks for a natural size first', (
    tester,
  ) async {
    // The Health snapshot card puts a quick action (FitText label) in an
    // IntrinsicWidth inside a Wrap; a plain LayoutBuilder threw there.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Wrap(
                children: [
                  IntrinsicWidth(
                    child: Row(
                      children: [
                        const Icon(Icons.add),
                        Flexible(child: FitText('Log weight', style: _style)),
                      ],
                    ),
                  ),
                ],
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: FitText('Streak', style: _style)),
                    const VerticalDivider(),
                    Expanded(child: FitText('Points', style: _style)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Log weight'), findsOneWidget);
    // Sized to the text, not squeezed to nothing.
    expect(tester.getSize(find.text('Log weight')).width, greaterThan(50));
  });
}
