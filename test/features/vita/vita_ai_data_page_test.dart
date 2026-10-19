import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/vita/data/services/vita_ai_consent.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_ai_data_page.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_ai_consent_sheet.dart';

import '../../helpers/pump_app.dart';

Future<VitaAiConsent> _register({bool accepted = false}) async {
  SharedPreferences.setMockInitialValues({});
  final consent = VitaAiConsent(
    await SharedPreferences.getInstance(),
    userId: () => 'u1',
  );
  if (accepted) await consent.accept(includeHealthConnect: false);
  await sl.reset();
  sl.registerSingleton<VitaAiConsent>(consent);
  addTearDown(sl.reset);
  return consent;
}

/// The switch on the row titled [title].
Finder _switchOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
  matching: find.byType(Switch),
);

void main() {
  group('AI coach data page', () {
    testWidgets('sharing off: Health Connect can only be chosen with it', (
      tester,
    ) async {
      final consent = await _register();
      await pumpPage(tester, const VitaAiDataPage());
      final hc = tester.widget<Switch>(
        _switchOf('Include Health Connect readings'),
      );
      expect(hc.onChanged, isNull);

      await tester.tap(_switchOf('Use Vita and AI plans'));
      await tester.pumpAndSettle();
      expect(consent.accepted, isTrue);
      expect(consent.includeHealthConnect, isFalse);
    });

    testWidgets('switches save at once; turning sharing off withdraws', (
      tester,
    ) async {
      final consent = await _register(accepted: true);
      await pumpPage(tester, const VitaAiDataPage());

      await tester.tap(_switchOf('Include Health Connect readings'));
      await tester.pumpAndSettle();
      expect(consent.includeHealthConnect, isTrue);

      await tester.tap(_switchOf('Use Vita and AI plans'));
      await tester.pumpAndSettle();
      expect(consent.accepted, isFalse);
      expect(consent.includeHealthConnect, isFalse);
    });

    testWidgets('fits a small phone at the largest text size', (tester) async {
      await _register(accepted: true);
      await pumpPage(tester, const VitaAiDataPage(), textScale: kMaxTextScale);
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  });

  group('first-use consent sheet', () {
    Future<Future<bool>> open(WidgetTester tester) async {
      late Future<bool> result;
      await pumpPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => result = showVitaAiConsentSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('short: summary, Health Connect choice, agree or not now', (
      tester,
    ) async {
      final consent = await _register();
      final result = await open(tester);
      expect(find.text("See what's shared"), findsOneWidget);
      expect(find.text('Health answers'), findsNothing);

      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(consent.accepted, isTrue);
    });

    testWidgets("details open on top; turning sharing on there agrees", (
      tester,
    ) async {
      await _register();
      final result = await open(tester);
      await tester.tap(find.text("See what's shared"));
      await tester.pumpAndSettle();
      expect(find.text('Health answers'), findsOneWidget);

      await tester.tap(_switchOf('Use Vita and AI plans'));
      await tester.pumpAndSettle();
      // System back, as the app header has its own back button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.text('Agree and continue'), findsNothing);
    });
  });
}
