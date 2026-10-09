import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';

/// Sign-in / sign-up field rules and cleaning. Messages are shown inline.
abstract final class AuthRules {
  /// Practical email check: local part, domain with at least one dot and a
  /// TLD of 2+ letters (long TLDs like .museum or .health are fine).
  static final _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
  );

  /// Trimmed, invisible characters removed and lower-cased (auth emails
  /// are case-insensitive).
  static String cleanEmail(String input) =>
      sanitizeText(input, maxLength: InputLimits.email).toLowerCase();

  static bool isEmail(String input) {
    final email = cleanEmail(input);
    return email.length <= InputLimits.email &&
        !email.contains('..') &&
        !email.startsWith('.') &&
        !email.contains('.@') &&
        _email.hasMatch(email);
  }

  /// Why [input] isn't a usable email, or null.
  static String? emailError(String input) {
    if (cleanEmail(input).isEmpty) return 'Enter your email';
    if (input.trim().length > InputLimits.email || !isEmail(input)) {
      return 'Enter a valid email';
    }
    return null;
  }

  /// Why [password] can't be used for a new account, or null. Passwords
  /// are never trimmed or otherwise changed.
  static String? passwordError(String password) {
    if (password.isEmpty) return 'Enter a password';
    if (password.length < InputLimits.passwordMin) {
      return 'Use at least ${InputLimits.passwordMin} characters';
    }
    if (password.length > InputLimits.passwordMax) {
      return 'Use at most ${InputLimits.passwordMax} characters';
    }
    return null;
  }

  /// The login field holds an email or a username.
  static String cleanLoginId(String input) {
    final value = sanitizeText(input, maxLength: InputLimits.email);
    return value.contains('@') ? value.toLowerCase() : value;
  }

  /// Whether [input] could be an email or a username at all (anything else
  /// can't match an account, so there's no point asking the server).
  static bool isPlausibleLoginId(String input) {
    final value = cleanLoginId(input);
    if (value.contains('@')) return isEmail(value);
    return UsernameService.formatError(value) == null;
  }

  /// Whether [password] could belong to an account. Only the upper limit
  /// is checked: accounts made before the 8-character rule (or with the
  /// server's own minimum) must still be able to sign in.
  static bool isPlausiblePassword(String password) =>
      password.isNotEmpty && password.length <= InputLimits.passwordMax;
}
