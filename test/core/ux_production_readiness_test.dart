import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/router/app_router.dart';

void main() {
  group('Input Field Focus Dismissal UX', () {
    testWidgets('Tapping AppPrimaryButton unfocuses input field', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      var buttonClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppTextField(
                  controller: controller,
                  focusNode: focusNode,
                  label: 'Name',
                ),
                AppPrimaryButton(
                  label: 'Submit',
                  onTap: () => buttonClicked = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap the primary button
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      expect(buttonClicked, isTrue);
    });

    testWidgets('Tapping AppSecondaryButton unfocuses input field', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      var buttonClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppTextField(
                  controller: controller,
                  focusNode: focusNode,
                  label: 'Email',
                ),
                AppSecondaryButton(
                  label: 'Cancel',
                  onTap: () => buttonClicked = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      expect(buttonClicked, isTrue);
    });

    testWidgets('Tapping background in AppScaffold unfocuses input field', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            scrollable: false,
            body: Column(
              children: [
                AppTextField(
                  controller: controller,
                  focusNode: focusNode,
                  label: 'Username',
                ),
                const SizedBox(height: 200, key: Key('empty_space')),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap on empty space outside the text field
      await tester.tap(find.byKey(const Key('empty_space')), warnIfMissed: false);
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });
  });

  group('Snackbar Navigation Removal UX', () {
    testWidgets('Navigating to another page removes active snackbar', (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          navigatorObservers: [AppNavigationObserver()],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showSuccessSnackBar(context, 'Saved successfully');
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      // Show snackbar
      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      expect(find.text('Saved successfully'), findsOneWidget);

      // Push new route
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Text('Page 2'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SnackBar from Page 1 should be gone on Page 2
      expect(find.text('Saved successfully'), findsNothing);
      expect(find.text('Page 2'), findsOneWidget);
    });

    testWidgets('Popping back from a page removes active snackbar', (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          navigatorObservers: [AppNavigationObserver()],
          home: const Scaffold(body: Text('Home')),
        ),
      );

      // Push second page
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (pageContext) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showErrorSnackBar(pageContext, 'Error on Page 2');
              },
              child: const Text('Show Error'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Show snackbar on page 2
      await tester.tap(find.text('Show Error'));
      await tester.pump();
      expect(find.text('Error on Page 2'), findsOneWidget);

      // Pop back to home
      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SnackBar from Page 2 must be dismissed
      expect(find.text('Error on Page 2'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
