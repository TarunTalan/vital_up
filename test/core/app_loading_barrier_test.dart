import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/services/app_loading_controller.dart';
import 'package:vital_up/core/widgets/app_loading_barrier.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';

void main() {
  setUp(() {
    AppLoadingController.instance.reset();
  });

  tearDown(() {
    AppLoadingController.instance.reset();
  });

  group('AppLoadingController', () {
    test('starts and stops manual loading tokens', () {
      expect(AppLoadingController.instance.isLoading, isFalse);

      final token = Object();
      AppLoadingController.instance.startLoading(token);
      expect(AppLoadingController.instance.isLoading, isTrue);

      AppLoadingController.instance.stopLoading(token);
      expect(AppLoadingController.instance.isLoading, isFalse);
    });

    test('tracks in-flight API requests', () {
      expect(AppLoadingController.instance.isLoading, isFalse);

      AppLoadingController.instance.startRequest();
      AppLoadingController.instance.startRequest();
      expect(AppLoadingController.instance.isLoading, isTrue);
      expect(AppLoadingController.instance.activeOperationsCount, equals(2));

      AppLoadingController.instance.endRequest();
      expect(AppLoadingController.instance.isLoading, isTrue);

      AppLoadingController.instance.endRequest();
      expect(AppLoadingController.instance.isLoading, isFalse);
    });

    test('track future completes and restores state', () async {
      expect(AppLoadingController.instance.isLoading, isFalse);

      final result = await AppLoadingController.instance.track(() async {
        expect(AppLoadingController.instance.isLoading, isTrue);
        return 'success';
      });

      expect(result, equals('success'));
      expect(AppLoadingController.instance.isLoading, isFalse);
    });
  });

  group('AppLoadingBarrier widget', () {
    testWidgets('allows interaction when not loading', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLoadingBarrier(
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => tapped = true,
                  child: const Text('Tap Me'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('absorbs all interactions when loading is active', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLoadingBarrier(
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => tapped = true,
                  child: const Text('Tap Me'),
                ),
              ),
            ),
          ),
        ),
      );

      AppLoadingController.instance.startLoading();
      await tester.pump();

      await tester.tap(find.text('Tap Me'), warnIfMissed: false);
      await tester.pump();

      expect(tapped, isFalse);

      AppLoadingController.instance.stopLoading();
      await tester.pump();

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('AppScaffold un-interactivity', () {
    testWidgets('makes whole screen un-interactive when isLoading is true', (tester) async {
      var headerTapped = false;
      var bottomTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            isLoading: true,
            header: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => headerTapped = true,
            ),
            bottomBar: ElevatedButton(
              onPressed: () => bottomTapped = true,
              child: const Text('Save'),
            ),
            body: const Text('Page Content'),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton), warnIfMissed: false);
      await tester.pump();
      expect(headerTapped, isFalse);

      await tester.tap(find.text('Save'), warnIfMissed: false);
      await tester.pump();
      expect(bottomTapped, isFalse);
    });

    testWidgets('makes whole screen un-interactive when isBusy is true', (tester) async {
      var contentTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            isBusy: true,
            body: ElevatedButton(
              onPressed: () => contentTapped = true,
              child: const Text('Action'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Action'), warnIfMissed: false);
      await tester.pump();
      expect(contentTapped, isFalse);
    });
  });

  group('Button loading propagates un-interactivity', () {
    testWidgets('AppPrimaryButton loading state locks AppLoadingBarrier', (tester) async {
      var otherButtonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLoadingBarrier(
            child: Scaffold(
              body: Column(
                children: [
                  AppPrimaryButton(
                    label: 'Submit',
                    isLoading: true,
                    onTap: () {},
                  ),
                  ElevatedButton(
                    onPressed: () => otherButtonTapped = true,
                    child: const Text('Other Action'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(AppLoadingController.instance.isLoading, isTrue);

      await tester.tap(find.text('Other Action'), warnIfMissed: false);
      await tester.pump();

      expect(otherButtonTapped, isFalse);
    });
  });
}
