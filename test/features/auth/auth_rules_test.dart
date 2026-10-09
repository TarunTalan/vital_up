import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/auth/domain/auth_rules.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';

void main() {
  group('email', () {
    test('accepts common and long-TLD addresses', () {
      expect(AuthRules.emailError('a.b+tag@example.com'), isNull);
      expect(AuthRules.emailError('me@sub.domain.museum'), isNull);
      expect(AuthRules.emailError('  Me@Example.COM  '), isNull);
    });

    test('rejects malformed addresses', () {
      expect(AuthRules.emailError(''), 'Enter your email');
      expect(AuthRules.emailError('plain'), isNotNull);
      expect(AuthRules.emailError('a@b'), isNotNull);
      expect(AuthRules.emailError('a..b@example.com'), isNotNull);
      expect(AuthRules.emailError('a@-x.com'), isNotNull);
      expect(AuthRules.emailError('${'a' * 250}@x.com'), isNotNull);
    });

    test('cleanEmail trims and lower-cases', () {
      expect(AuthRules.cleanEmail(' Me@Example.COM\u200B '), 'me@example.com');
    });
  });

  group('password', () {
    test('sign-up length rules', () {
      expect(AuthRules.passwordError(''), isNotNull);
      expect(AuthRules.passwordError('short'), isNotNull);
      expect(AuthRules.passwordError('long enough'), isNull);
      expect(AuthRules.passwordError('x' * 40), isNull);
      expect(AuthRules.passwordError('x' * 129), isNotNull);
    });

    test('login accepts passwords longer than 16 characters', () {
      expect(AuthRules.isPlausiblePassword('x' * 24), isTrue);
      expect(AuthRules.isPlausiblePassword(''), isFalse);
    });
  });

  test('login id is a username or an email', () {
    expect(AuthRules.isPlausibleLoginId('tarun_01'), isTrue);
    expect(AuthRules.isPlausibleLoginId('A+b@x-y.com'), isTrue);
    expect(AuthRules.isPlausibleLoginId('ab'), isFalse);
    expect(AuthRules.isPlausibleLoginId('bad name'), isFalse);
  });

  group('failure messages', () {
    test('never show raw server text', () {
      const raw =
          'PostgrestException(message: relation "x" does not exist, code: 42P01)';
      expect(AuthCubit.messageForFailure(raw), 'Something went wrong. Try again.');
    });

    test('maps common cases to short messages', () {
      expect(
        AuthCubit.messageForFailure('SocketException: Failed host lookup'),
        "You're offline. Try again when connected.",
      );
      expect(
        AuthCubit.messageForFailure('Invalid login credentials'),
        AuthCubit.credentialsMessage,
      );
      expect(
        AuthCubit.messageForFailure('Token has expired or is invalid', otp: true),
        'Wrong or expired code. Try again.',
      );
      // Outside the code screens "token" doesn't mean a wrong code.
      expect(
        AuthCubit.messageForFailure('Token has expired or is invalid'),
        isNot(contains('code')),
      );
    });

    test('messages are short sentences without exclamation marks', () {
      for (final raw in [
        'rate limit exceeded',
        'User already registered',
        'Email is not registered. Please sign up.',
        'For security purposes, you can only request this after 42 seconds.',
        'New password should be different from the old password.',
        'Username is already taken.',
        'TimeoutException after 0:00:20',
      ]) {
        final message = AuthCubit.messageForFailure(raw);
        expect(message.length, lessThanOrEqualTo(60), reason: raw);
        expect(message.contains('!'), isFalse, reason: raw);
      }
    });
  });
}
