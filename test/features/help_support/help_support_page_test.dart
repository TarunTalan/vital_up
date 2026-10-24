import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/help_support/presentation/pages/help_support_page.dart';

import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HelpSupportPage action cards', () {
    testWidgets('renders the Ask Vita card at top and contact form at bottom', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const HelpSupportPage(),
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      // Top: Ask Vita card (Vita answers app questions too)
      expect(find.text('Ask Vita'), findsOneWidget);
      expect(
        find.text('Questions about the app or your health'),
        findsOneWidget,
      );
      expect(find.text('AI'), findsNothing);

      // Verify no duplicate "Contact Team" card at the top
      expect(find.text('Contact Team'), findsNothing);

      // Bottom: Still have questions & Open Contact Form
      expect(find.text('Still have questions?'), findsOneWidget);
      expect(find.text('Open Contact Form'), findsOneWidget);
      expect(find.textContaining('Direct contact:'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow on small phone screen', (
      tester,
    ) async {
      await pumpPage(tester, const HelpSupportPage(), size: kSmallPhone);
      await tester.pumpAndSettle();

      expect(find.text('Ask Vita'), findsOneWidget);
      expect(find.text('Still have questions?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
