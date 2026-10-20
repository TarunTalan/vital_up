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
}
