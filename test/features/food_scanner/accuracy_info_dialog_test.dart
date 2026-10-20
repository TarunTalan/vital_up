import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_dimens.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/accuracy_info_dialog.dart';

void main() {
  testWidgets('AccuracyInfoDialog applies top insets when status bar padding exists', (tester) async {
    const statusBarHeight = 44.0;
    const navBarHeight = 34.0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: statusBarHeight, bottom: navBarHeight),
          ),
          child: const Scaffold(
            body: AccuracyInfoDialog(),
          ),
        ),
      ),
    );

    expect(find.text('How accurate is this?'), findsOneWidget);
    expect(find.text('Dual AI Verification'), findsOneWidget);
    expect(find.text('Laboratory Mapped'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    final dialogFinder = find.byType(Dialog);
    expect(dialogFinder, findsOneWidget);

    final Dialog dialog = tester.widget(dialogFinder);
    final insets = dialog.insetPadding as EdgeInsets;

    expect(insets.top, statusBarHeight + AppDimens.space24);
    expect(insets.bottom, navBarHeight + AppDimens.space24);
    expect(insets.left, AppDimens.gutter);
    expect(insets.right, AppDimens.gutter);
  });

  testWidgets('Got it button is fixed at bottom outside SingleChildScrollView and dismisses dialog', (tester) async {
    var popped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const AccuracyInfoDialog(),
                );
                popped = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Got it button must NOT be inside the SingleChildScrollView
    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    expect(
      find.descendant(of: scrollView, matching: find.text('Got it')),
      findsNothing,
      reason: 'Got it button must be fixed at the bottom outside SingleChildScrollView',
    );

    // Tap Got it button directly without scrolling
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });
}
