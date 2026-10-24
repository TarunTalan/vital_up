import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/help_support/presentation/pages/contact_support_page.dart';

import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactSupportPage layout', () {
    testWidgets('renders all fields and submit button in scrollable body', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ContactSupportPage(),
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      // Top fields
      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Your Contact Email'), findsOneWidget);
      expect(find.text('Issue category'), findsOneWidget);
      expect(find.text('Subject (optional)'), findsOneWidget);

      // Description field is present in the scrollable body
      expect(find.text('Description & details'), findsOneWidget);

      // Scroll to reveal bottom actions if needed
      final submitFinder = find.text('Submit Support Ticket');
      await tester.scrollUntilVisible(
        submitFinder,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(submitFinder, findsOneWidget);
      expect(find.text('Include Device & App Diagnostics'), findsOneWidget);
      expect(find.textContaining('Direct contact:'), findsOneWidget);

      // Verify no overflow
      expect(tester.takeException(), isNull);
    });
  });
}
