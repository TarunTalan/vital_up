import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/network/offline_errors.dart';

/// Shared input limits, sanitising and user-facing error text. Every text
/// field and anything typed that reaches storage, the server or the AI goes
/// through these, so limits and messages stay the same app-wide.
abstract final class InputLimits {
  // Text lengths (characters).
  static const name = 50;
  static const usernameMin = 3;
  static const usernameMax = 20;
  static const email = 254;
  static const passwordMin = 8;
  static const passwordMax = 128;
  static const search = 100;
  static const shortText = 80; // titles, labels, food names
  static const note = 500; // notes, feedback, descriptions
  static const chatMessage = 1000; // Vita / support chat
  static const city = 60;

  // Body and tracking ranges (metric; convert imperial before checking).
  static const heightCmMin = 50.0;
  static const heightCmMax = 272.0;
  static const weightKgMin = 20.0;
  static const weightKgMax = 350.0;
  static const ageMin = 13;
  static const ageMax = 120;
  static const waterMlMin = 1;
  static const waterMlMax = 5000; // one entry
  static const waterGoalMlMin = 500;
  static const waterGoalMlMax = 10000;
  static const caloriesMax = 10000; // per food entry or daily goal
  static const gramsMax = 5000; // per food entry
  static const stepsGoalMax = 100000;
  static const sleepGoalMinMin = 180;
  static const sleepGoalMinMax = 840;
}

/// Zero-width and other invisible format characters, bidi overrides and
/// C0/C1 control characters (except tab / newline, handled separately).
final _invisible = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F'
  '\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\uFEFF]',
);
final _spaces = RegExp('[ \t\u00A0]+');
final _blankLines = RegExp(r'\n{3,}');

/// Cleans typed text before it is saved or sent: drops invisible / control
/// characters, collapses runs of spaces, trims, and cuts to [maxLength].
/// [multiline] keeps single line breaks (at most one blank line in a row);
/// otherwise line breaks become spaces.
String sanitizeText(String input, {int? maxLength, bool multiline = false}) {
  var s = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  s = s.replaceAll(_invisible, '');
  if (multiline) {
    s = s
        .split('\n')
        .map((line) => line.replaceAll(_spaces, ' ').trim())
        .join('\n')
        .replaceAll(_blankLines, '\n\n');
  } else {
    s = s.replaceAll('\n', ' ').replaceAll(_spaces, ' ');
  }
  s = s.trim();
  if (maxLength != null && s.characters.length > maxLength) {
    s = s.characters.take(maxLength).toString().trimRight();
  }
  return s;
}

/// [sanitizeText], or null when nothing is left (for optional fields).
String? sanitizeOptional(String? input, {int? maxLength, bool multiline = false}) {
  if (input == null) return null;
  final s = sanitizeText(input, maxLength: maxLength, multiline: multiline);
  return s.isEmpty ? null : s;
}

/// Parses a typed number ("1,5" or "1.5") and returns it only when it is
/// finite and within [min, max].
double? parseNumberInRange(String? input, {required num min, required num max}) {
  final text = input?.trim().replaceAll(',', '.');
  if (text == null || text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value < min || value > max) {
    return null;
  }
  return value;
}

/// Input formatters for text fields.
abstract final class InputFormatters {
  /// Blocks invisible / control characters as they are typed or pasted.
  static final noInvisible = FilteringTextInputFormatter.deny(_invisible);

  /// Single-line fields: also blocks line breaks.
  static final singleLine = FilteringTextInputFormatter.deny(RegExp('[\n\r]'));

  static List<TextInputFormatter> text(int maxLength, {bool multiline = false}) => [
    noInvisible,
    if (!multiline) singleLine,
    LengthLimitingTextInputFormatter(maxLength),
  ];
}

/// Short, plain message for [error] to show the user (snackbar, inline
/// error). Never shows exception text: technical detail goes to logs.
String userMessage(Object error, {String fallback = 'Something went wrong. Try again.'}) {
  if (isOfflineError(error)) return "You're offline. Try again when connected.";
  if (error is TimeoutException) return 'This is taking too long. Try again.';
  if (error is AuthException) {
    final code = error.statusCode;
    if (code == '401' || code == '403') return 'Please sign in again.';
    if (code == '429') return 'Too many attempts. Wait a moment.';
    return fallback;
  }
  if (error is PostgrestException) {
    if (error.code == '23505') return 'That already exists.';
    if (error.code == '42501' || error.code == 'PGRST301') {
      return "You don't have access to that.";
    }
    return fallback;
  }
  if (error is FunctionException) {
    if (error.status == 429) return 'Too many requests. Wait a moment.';
    return fallback;
  }
  return fallback;
}
