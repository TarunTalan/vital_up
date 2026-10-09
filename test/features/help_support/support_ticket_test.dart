import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/help_support/domain/entities/support_ticket.dart';

void main() {
  test('mail link encodes spaces as %20, not +', () {
    final uri = supportMailUri(subject: 'Sync issue', body: 'a & b');
    expect(
      uri.toString(),
      'mailto:$kSupportEmail?subject=Sync%20issue&body=a%20%26%20b',
    );
    expect(supportMailUri().toString(), 'mailto:$kSupportEmail');
  });

  test('description needs real text', () {
    expect(SupportTicketRules.validateDescription('   '), isNotNull);
    expect(SupportTicketRules.validateDescription('short'), isNotNull);
    expect(
      SupportTicketRules.validateDescription('The app crashes on start'),
      isNull,
    );
  });

  test('subject and description are cleaned and capped', () {
    expect(SupportTicketRules.cleanSubject('  a\nb  '), 'a b');
    expect(
      SupportTicketRules.cleanSubject('x' * 200).length,
      SupportTicketRules.subjectMax,
    );
    expect(
      SupportTicketRules.cleanDescription('x' * 5000).length,
      SupportTicketRules.descriptionMax,
    );
  });
}
