import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/utils/input_rules.dart';

void main() {
  group('sanitizeText', () {
    test('keeps joiners that emoji and Indic scripts need', () {
      // Family emoji: man ZWJ woman ZWJ girl.
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      expect(sanitizeText('Hi $family'), 'Hi $family');
      // Hindi half form with ZWJ, Persian half-space with ZWNJ.
      const hindi = '\u0915\u094D\u200D\u0937';
      expect(sanitizeText(hindi), hindi);
      const persian = '\u0645\u06CC\u200C\u0634\u0648\u062F';
      expect(sanitizeText(persian), persian);
      // Zero-width space and bidi overrides are still removed.
      expect(sanitizeText('a\u200Bb\u202Ec'), 'abc');
    });

    test('trims, collapses spaces and drops invisible characters', () {
      expect(sanitizeText('  Oat\u200B  milk \u0007 '), 'Oat milk');
      expect(sanitizeText('a\nb'), 'a b');
    });

    test('multiline keeps lines but at most one blank line', () {
      expect(sanitizeText(' a \n\n\n\n b ', multiline: true), 'a\n\nb');
    });

    test('cuts to the limit without splitting emoji-like clusters', () {
      expect(sanitizeText('abcdef', maxLength: 3), 'abc');
      expect(sanitizeText('ab\u{1F600}cd', maxLength: 3), 'ab\u{1F600}');
    });

    test('optional fields become null when blank', () {
      expect(sanitizeOptional('  \u200B '), isNull);
      expect(sanitizeOptional(' x '), 'x');
    });
  });

  test('parseNumberInRange accepts commas and rejects out of range', () {
    expect(parseNumberInRange('72,5', min: 20, max: 350), 72.5);
    expect(parseNumberInRange('0', min: 20, max: 350), isNull);
    expect(parseNumberInRange('abc', min: 0, max: 1), isNull);
    expect(parseNumberInRange('NaN', min: 0, max: 1), isNull);
    expect(parseNumberInRange('', min: 0, max: 1), isNull);
  });

  test('userMessage never shows exception text', () {
    expect(userMessage(const SocketException('x')), contains('offline'));
    expect(userMessage(TimeoutException('x')), isNot(contains('Timeout')));
    expect(userMessage(Exception('secret detail')), isNot(contains('secret')));
    expect(userMessage(StateError('x'), fallback: "Couldn't save."), "Couldn't save.");
  });

  test('an expired sign-in asks to sign in again', () {
    for (final code in ['PGRST301', 'PGRST303']) {
      expect(
        userMessage(PostgrestException(message: 'JWT expired', code: code)),
        'Please sign in again.',
      );
    }
    expect(
      userMessage(const PostgrestException(message: 'denied', code: '42501')),
      "You don't have access to that.",
    );
  });
}
