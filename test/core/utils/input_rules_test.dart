import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/input_rules.dart';

void main() {
  group('sanitizeText', () {
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
}
