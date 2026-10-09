import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter/foundation.dart';
import 'package:vital_up/features/auth/domain/auth_rules.dart';
import 'package:vital_up/features/auth/domain/entities/user_entity.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  /// Runs while still signed in, e.g. to stop push notifications.
  final Future<void> Function()? _beforeSignOut;

  AuthCubit({required this._authRepository, this._beforeSignOut})
      : super(AuthInitial());

  // Input Fields State Controllers
  final StreamController<String> _usernameLoginController = StreamController<String>.broadcast();
  final StreamController<String> _passwordController = StreamController<String>.broadcast();
  final StreamController<String> _emailController = StreamController<String>.broadcast();
  final StreamController<String> _usernameSignupController = StreamController<String>.broadcast();

  // Field Errors State Controllers
  final StreamController<String?> _usernameErrorLoginController = StreamController<String?>.broadcast();
  final StreamController<String?> _passwordErrorController = StreamController<String?>.broadcast();
  final StreamController<String?> _emailErrorController = StreamController<String?>.broadcast();
  final StreamController<String?> _usernameErrorSignupController = StreamController<String?>.broadcast();
  final StreamController<String?> _otpErrorController = StreamController<String?>.broadcast();

  // Checking state
  final StreamController<bool> _isCheckingUsernameController = StreamController<bool>.broadcast();
  final StreamController<bool?> _isUsernameAvailableController = StreamController<bool?>.broadcast();

  // Resend Timer Controllers
  final StreamController<int> _registrationOtpResendTimerController = StreamController<int>.broadcast();
  final StreamController<int> _forgotOtpResendTimerController = StreamController<int>.broadcast();

  // Current values cache
  String _usernameLogin = '';
  String _password = '';
  String _email = '';
  String _usernameSignup = '';

  // Active timers & debounces
  Timer? _registrationTimer;
  Timer? _forgotTimer;
  Timer? _debounceTimer;

  int _registrationResendSecs = 0;
  int _forgotResendSecs = 0;

  // Tracks the last known username availability result (null = unknown/pending)
  bool? _isUsernameAvailable;
  String? _lastUsernameError;

  // Attempt counter — UX only (no client-side lockout; Supabase enforces rate limits)
  final Map<String, int> _otpFailCounts = {};
  static const int _maxOtpAttempts = 3;

  // Getters for UI exposure
  String get usernameLoginVal => _usernameLogin;
  String get passwordVal => _password;
  String get emailVal => _email;
  String get usernameSignupVal => _usernameSignup;

  Stream<String> get usernameLoginStream => _usernameLoginController.stream;
  Stream<String> get passwordStream => _passwordController.stream;
  Stream<String> get emailStream => _emailController.stream;
  Stream<String> get usernameSignupStream => _usernameSignupController.stream;

  Stream<String?> get usernameErrorLoginStream => _usernameErrorLoginController.stream;
  Stream<String?> get passwordErrorStream => _passwordErrorController.stream;
  Stream<String?> get emailErrorStream => _emailErrorController.stream;
  Stream<String?> get usernameErrorSignupStream => _usernameErrorSignupController.stream;
  Stream<String?> get otpErrorStream => _otpErrorController.stream;

  Stream<bool> get isCheckingUsernameStream => _isCheckingUsernameController.stream;
  Stream<bool?> get isUsernameAvailableStream => _isUsernameAvailableController.stream;

  Stream<int> get registrationOtpResendTimerStream => _registrationOtpResendTimerController.stream;
  Stream<int> get forgotOtpResendTimerStream => _forgotOtpResendTimerController.stream;

  int get registrationResendSecs => _registrationResendSecs;
  int get forgotResendSecs => _forgotResendSecs;

  // Value change handlers
  void onUsernameLoginChange(String val) {
    _usernameLogin = val;
    _usernameLoginController.add(val);
    _usernameErrorLoginController.add(null);
    _passwordErrorController.add(null);
  }

  void onPasswordChange(String val) {
    _password = val;
    _passwordController.add(val);
    _passwordErrorController.add(null);
    _usernameErrorLoginController.add(null);
  }

  void onEmailChange(String val) {
    _email = val;
    _emailController.add(val);
    _emailErrorController.add(null);
  }

  void onUsernameSignupChange(String val) {
    _usernameSignup = val;
    _usernameSignupController.add(val);
    _usernameErrorSignupController.add(null);
    _isUsernameAvailableController.add(null);
    _isUsernameAvailable = null; // Reset — new input invalidates previous check
    _lastUsernameError = null; // Reset error on typing

    // Debounced username availability checks
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (validateUsernameSignup()) {
        _checkUsernameAvailability(val);
      }
    });
  }

  // Validation functions matching AuthViewModel
  /// Shown under the password field when the login can't match an account.
  static const credentialsMessage = 'Wrong username or password. Try again.';

  bool validateUsernameLogin() {
    if (AuthRules.cleanLoginId(_usernameLogin).isEmpty) {
      _usernameErrorLoginController.add('Enter your username or email');
      return false;
    }
    if (!AuthRules.isPlausibleLoginId(_usernameLogin)) {
      _usernameErrorLoginController.add('');
      _passwordErrorController.add(credentialsMessage);
      return false;
    }

    _usernameErrorLoginController.add(null);
    return true;
  }

  bool validateUsernameSignup() {
    final error = UsernameService.formatError(_usernameSignup);
    _usernameErrorSignupController.add(error);
    return error == null;
  }

  bool validateEmail() {
    final error = AuthRules.emailError(_email);
    _emailErrorController.add(error);
    return error == null;
  }

  bool validatePassword() {
    final error = AuthRules.passwordError(_password);
    _passwordErrorController.add(error);
    return error == null;
  }

  bool validatePasswordForLogin() {
    if (_password.isEmpty) {
      _passwordErrorController.add('Enter your password');
      return false;
    }
    if (!AuthRules.isPlausiblePassword(_password)) {
      _usernameErrorLoginController.add('');
      _passwordErrorController.add(credentialsMessage);
      return false;
    }
    _passwordErrorController.add(null);
    return true;
  }

  void clearErrorsOnly() {
    _usernameErrorLoginController.add(null);
    _passwordErrorController.add(null);
    _emailErrorController.add(null);
    _usernameErrorSignupController.add(null);
    _otpErrorController.add(null);
  }

  void clearPasswordError() {
    _passwordErrorController.add(null);
  }

  void clearOtpError() {
    _otpErrorController.add(null);
  }

  void setOtpError(String error) {
    _otpErrorController.add(error);
  }

  void clearResetFields() {
    _password = '';
    _passwordController.add('');
    clearErrorsOnly();
  }

  // Username availability check remote call
  Future<void> _checkUsernameAvailability(String username) async {
    _isCheckingUsernameController.add(true);
    _usernameErrorSignupController.add(null);
    _isUsernameAvailable = null; // Reset while checking

    final result = await _authRepository.checkUsernameAvailability(username);
    if (isClosed) return;
    result.fold(
      (failure) {
        if (_usernameSignup == username) {
          _isUsernameAvailable = false;
          final mappedMessage = _mapFailureToMessage(failure.message);
          _lastUsernameError = mappedMessage;
          _usernameErrorSignupController.add(mappedMessage);
          _isUsernameAvailableController.add(false);
        }
      },
      (_) {
        if (_usernameSignup == username) {
          _isUsernameAvailable = true;
          _usernameErrorSignupController.add(null); // Clear error — username is free
          _isUsernameAvailableController.add(true);
        }
      },
    );
    _isCheckingUsernameController.add(false);
  }

  static final _nestedMessage = RegExp(
    r'(?:message:\s*|message\s*=\s*|message:\s*")([^",\)]+)',
  );

  /// Extracts the message from "AuthApiException(message: XYZ, ...)".
  static String _sanitizeRawErrorMessage(String message) =>
      _nestedMessage.firstMatch(message)?.group(1)?.trim() ?? message;

  /// Short user-facing text for a failure from the auth repository. Raw
  /// server text is never shown; [otp] maps code/token errors to a wrong
  /// code message (only meaningful while verifying a code).
  @visibleForTesting
  static String messageForFailure(String originalMessage, {bool otp = false}) {
    final origLower = originalMessage.toLowerCase();

    // Network problems first: they're often wrapped in other errors.
    if (origLower.contains('socketexception') ||
        origLower.contains('network') ||
        origLower.contains('connection') ||
        origLower.contains('handshake') ||
        origLower.contains('failed host lookup') ||
        origLower.contains('clientexception') ||
        origLower.contains("you're offline")) {
      return "You're offline. Try again when connected.";
    }
    if (origLower.contains('timeoutexception') ||
        origLower.contains('taking too long')) {
      return 'This is taking too long. Try again.';
    }

    final cleanMsg = _sanitizeRawErrorMessage(originalMessage);
    final msg = cleanMsg.toLowerCase();

    if (msg.contains('cancelled') || msg.contains('canceled')) {
      return 'Google sign-in was cancelled.';
    }
    if (msg.contains('missing id token') ||
        msg.contains('missing_id_token') ||
        msg.contains('failed: missing') ||
        msg.contains('google')) {
      return "Couldn't sign in with Google. Try again.";
    }
    if (msg.contains('rate limit') ||
        msg.contains('too many requests') ||
        msg.contains('too_many_requests') ||
        msg.contains('over_request_rate_limit')) {
      return 'Too many attempts. Wait a few minutes.';
    }
    if (msg.contains('security purposes') || msg.contains('request this after')) {
      final match = RegExp(r'\d+').firstMatch(cleanMsg);
      if (match != null) {
        return 'Wait ${match.group(0)}s before asking for a new code.';
      }
      return 'Wait a moment before asking for a new code.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('username or password') ||
        msg.contains('no account exist')) {
      return credentialsMessage;
    }
    if (msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return 'Verify your email first, then sign in.';
    }
    if (msg.contains('username') && msg.contains('taken')) {
      return 'That username is taken';
    }
    if (msg.contains('already exists') ||
        msg.contains('already registered') ||
        msg.contains('email already in use') ||
        msg.contains('email_exists')) {
      return 'This email is already registered.';
    }
    if (msg.contains('not registered') ||
        msg.contains('please sign up') ||
        msg.contains('no user found')) {
      return 'No account with this email. Sign up instead.';
    }
    if (msg.contains('should be different from') ||
        msg.contains('different from the old') ||
        msg.contains('must be different') ||
        msg.contains('same as old') ||
        msg.contains('same_password')) {
      return "Use a password you haven't used before.";
    }
    if (msg.contains('password should be') ||
        msg.contains('weak password') ||
        msg.contains('weak_password') ||
        msg.contains('password too short')) {
      return 'Choose a stronger password.';
    }
    if (otp &&
        (msg.contains('token') ||
            msg.contains('otp') ||
            msg.contains('verification') ||
            msg.contains('confirmation') ||
            msg.contains('code') ||
            msg.contains('expired'))) {
      return 'Wrong or expired code. Try again.';
    }
    return 'Something went wrong. Try again.';
  }

  String _mapFailureToMessage(String originalMessage, {bool otp = false}) {
    debugPrint('Auth failure: $originalMessage');
    return messageForFailure(originalMessage, otp: otp);
  }

  /// A request is already running (double taps, enter + button).
  bool get _busy => state is AuthLoading;

  Future<void> signIn({required Function() onSuccess}) async {
    if (_busy) return;
    if (!validateUsernameLogin() || !validatePasswordForLogin()) return;

    emit(AuthLoading());
    final result = await _authRepository.signIn(
      AuthRules.cleanLoginId(_usernameLogin),
      _password,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        if (userFriendlyMessage == credentialsMessage) {
          // Highlight both fields in red, but display the text below the password field
          _usernameErrorLoginController.add('');
          _passwordErrorController.add(credentialsMessage);
        } else if (userFriendlyMessage.toLowerCase().contains('verify')) {
          _usernameErrorLoginController.add(userFriendlyMessage);
        } else {
          _passwordErrorController.add(userFriendlyMessage);
        }
        emit(AuthInitial());
      },
      (user) {
        emit(AuthAuthenticated(user));
        onSuccess();
      },
    );
  }

  Future<void> signUpWithOTP({
    required Function(String token) onOTPSent,
    required Function(String error) onError,
  }) async {
    if (_busy) return;
    // Guard: block if username availability check hasn't passed
    if (_isUsernameAvailable != true) {
      final msg = _lastUsernameError ?? 'Checking your username. Try again in a moment.';
      _usernameErrorSignupController.add(msg);
      onError(msg);
      return;
    }

    // The cleaned email is also what the OTP screen verifies against.
    _email = AuthRules.cleanEmail(_email);
    emit(AuthLoading());
    final result = await _authRepository.signUp(
      _usernameSignup.trim(),
      _email,
      _password,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        final msgLower = failure.message.toLowerCase();

        if (msgLower.contains('already registered') ||
            msgLower.contains('user already registered') ||
            msgLower.contains('email already') ||
            msgLower.contains('already in use')) {
          _emailErrorController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        } else if (msgLower.contains('username')) {
          _usernameErrorSignupController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        } else if (msgLower.contains('password')) {
          _passwordErrorController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        } else {
          _emailErrorController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        }
        emit(AuthInitial());
      },
      (token) {
        emit(AuthOtpSent(token: token, email: _email));
        onOTPSent(token);
        startRegistrationResendTimer();
      },
    );
  }

  Future<void> verifyOTP({
    required String otp,
    required String token,
    required String email,
    required Function() onSuccess,
    required Function(String err) onError,
  }) async {
    if (_busy) return;
    if (!_isSixDigits(otp)) {
      const msg = 'Enter all 6 digits';
      _otpErrorController.add(msg);
      onError(msg);
      return;
    }

    emit(AuthLoading());
    final result = await _authRepository.verifyRegistrationOTP(
      email: email,
      otp: otp,
      token: token,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        emit(AuthOtpSent(token: token, email: email));
        final key = email.trim().toLowerCase();
        _otpFailCounts[key] = (_otpFailCounts[key] ?? 0) + 1;
        final used = _otpFailCounts[key] ?? 1;
        final remaining = (_maxOtpAttempts - used).clamp(0, _maxOtpAttempts);

        final errorMsg = _mapFailureToMessage(failure.message, otp: true);
        final attemptsMessage = remaining > 0
            ? '$errorMsg ($remaining ${remaining == 1 ? 'attempt' : 'attempts'} left)'
            : errorMsg;

        _otpErrorController.add(attemptsMessage);
        onError(attemptsMessage);
      },
      (_) {
        _otpFailCounts.remove(email.trim().toLowerCase());
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          final user = UserEntity(
            id: currentUser.id,
            email: currentUser.email ?? email,
            displayName: currentUser.userMetadata?['username'] as String? ??
                email.split('@')[0],
          );
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthOtpVerified());
        }
        stopRegistrationResendTimer();
        onSuccess();
      },
    );
  }

  Future<void> resendOTP({
    required String token,
    required String email,
    required Function() onSuccess,
    required Function(String err) onError,
  }) async {
    // Reset attempt count on resend — fresh code, fresh slate
    _otpFailCounts.remove(email.trim().toLowerCase());

    emit(AuthLoading());
    final result = await _authRepository.resendRegistrationOTP(
      email: email,
      token: token,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message, otp: true);
        emit(AuthOtpSent(token: token, email: email));
        _otpErrorController.add(userFriendlyMessage);
        onError(userFriendlyMessage);
      },
      (_) {
        emit(AuthOtpSent(token: token, email: email));
        startRegistrationResendTimer();
        onSuccess();
      },
    );
  }

  Future<void> requestForgotPassword({required Function(String token) onSuccess}) async {
    if (_busy) return;
    if (!validateEmail()) return;

    _email = AuthRules.cleanEmail(_email);
    emit(AuthLoading());
    final result = await _authRepository.requestForgotPassword(_email);
    if (isClosed) return;

    result.fold(
      (failure) {
        // Shown under the field: this page has no other place for errors.
        _emailErrorController.add(_mapFailureToMessage(failure.message));
        emit(AuthInitial());
      },
      (token) {
        emit(AuthForgotPasswordOtpSent(token: token, email: _email));
        onSuccess(token);
        startForgotResendTimer();
      },
    );
  }

  Future<void> verifyForgotPassword({
    required String code,
    required Function(String resetToken) onSuccess,
    required Function(String err) onError,
    required String token,
  }) async {
    if (_busy) return;
    if (!_isSixDigits(code)) {
      const msg = 'Enter all 6 digits';
      _otpErrorController.add(msg);
      onError(msg);
      return;
    }

    emit(AuthLoading());
    final result = await _authRepository.verifyForgotPassword(
      email: _email,
      otp: code,
      token: token,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        emit(AuthForgotPasswordOtpSent(token: token, email: _email));
        final key = _email.trim().toLowerCase();
        _otpFailCounts[key] = (_otpFailCounts[key] ?? 0) + 1;
        final used = _otpFailCounts[key] ?? 1;
        final remaining = (_maxOtpAttempts - used).clamp(0, _maxOtpAttempts);

        final errorMsg = _mapFailureToMessage(failure.message, otp: true);
        final attemptsMessage = remaining > 0
            ? '$errorMsg ($remaining ${remaining == 1 ? 'attempt' : 'attempts'} left)'
            : errorMsg;

        _otpErrorController.add(attemptsMessage);
        onError(attemptsMessage);
      },
      (resetToken) {
        _otpFailCounts.remove(_email.trim().toLowerCase());
        emit(AuthForgotPasswordOtpVerified(token: resetToken, email: _email));
        stopForgotResendTimer();
        onSuccess(resetToken);
      },
    );
  }

  Future<void> resendForgotPassword({
    required Function(String token) onSuccess,
    required Function(String err) onError,
    required String currentToken,
  }) async {
    // Reset attempt count on resend — fresh code, fresh slate
    _otpFailCounts.remove(_email.trim().toLowerCase());

    emit(AuthLoading());
    final result = await _authRepository.resendForgotPasswordOTP(
      email: _email,
      token: currentToken,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message, otp: true);
        emit(AuthForgotPasswordOtpSent(token: currentToken, email: _email));
        _otpErrorController.add(userFriendlyMessage);
        onError(userFriendlyMessage);
      },
      (newToken) {
        emit(AuthForgotPasswordOtpSent(token: newToken, email: _email));
        startForgotResendTimer();
        onSuccess(newToken);
      },
    );
  }

  Future<void> resetPassword({
    required String resetToken,
    required Function() onSuccess,
  }) async {
    if (_busy) return;
    if (!validatePassword()) return;

    emit(AuthLoading());
    final result = await _authRepository.resetPassword(
      newPassword: _password,
      token: resetToken,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        _passwordErrorController.add(userFriendlyMessage);
        emit(AuthInitial());
      },
      (_) {
        emit(AuthPasswordResetSuccess());
        onSuccess();
      },
    );
  }


  Future<void> signInWithGoogle({required Function() onSuccess}) async {
    if (_busy) return;
    emit(AuthLoading());
    final result = await _authRepository.signInWithGoogle();
    if (isClosed) return;

    result.fold(
      (failure) {
        final lower = failure.message.toLowerCase();
        // Closing the account chooser isn't an error.
        if (lower.contains('cancelled') || lower.contains('canceled')) {
          emit(AuthInitial());
          return;
        }
        emit(AuthError(_mapFailureToMessage(failure.message)));
      },
      (user) {
        emit(AuthAuthenticated(user));
        onSuccess();
      },
    );
  }

  /// See [AuthRepository.hasCompletedOnboarding].
  Future<bool> hasCompletedOnboarding() => _authRepository.hasCompletedOnboarding();

  Future<void> checkSession() async {
    final active = await _authRepository.isSessionActive();
    if (isClosed) return;
    if (!active.getOrElse(() => false)) {
      emit(AuthUnauthenticated());
      return;
    }
    final userResult = await _authRepository.getCurrentUser();
    if (isClosed) return;
    final user = userResult.getOrElse(() => null);
    emit(user != null ? AuthAuthenticated(user) : AuthUnauthenticated());
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await _beforeSignOut?.call();
    } catch (e) {
      // Still sign out: a failed push unregister mustn't keep the user in.
      debugPrint('Before sign-out step failed: $e');
    }
    try {
      await _authRepository.signOut();
    } catch (e) {
      debugPrint('Sign-out failed: $e');
    }
    if (!isClosed) emit(AuthUnauthenticated());
  }

  /// The account was deleted and the device already wiped (AccountService).
  void accountDeleted() => emit(AuthUnauthenticated());

  void reset() {
    emit(AuthInitial());
    clearErrorsOnly();
  }

  void clearAllFields() {
    _usernameLogin = '';
    _password = '';
    _email = '';
    _usernameSignup = '';
    _usernameLoginController.add('');
    _passwordController.add('');
    _emailController.add('');
    _usernameSignupController.add('');
    _isUsernameAvailableController.add(null);
    clearErrorsOnly();
    emit(AuthInitial());
  }

  static bool _isSixDigits(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  // No client-side freeze helpers — Supabase enforces server-side rate limits.

  // Timer Management helpers
  void startRegistrationResendTimer() {
    _registrationTimer?.cancel();
    _registrationResendSecs = 60;
    _registrationOtpResendTimerController.add(_registrationResendSecs);

    _registrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_registrationResendSecs > 0) {
        _registrationResendSecs--;
        _registrationOtpResendTimerController.add(_registrationResendSecs);
      } else {
        timer.cancel();
      }
    });
  }

  void stopRegistrationResendTimer() {
    _registrationTimer?.cancel();
  }

  void startForgotResendTimer() {
    _forgotTimer?.cancel();
    _forgotResendSecs = 60;
    _forgotOtpResendTimerController.add(_forgotResendSecs);

    _forgotTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_forgotResendSecs > 0) {
        _forgotResendSecs--;
        _forgotOtpResendTimerController.add(_forgotResendSecs);
      } else {
        timer.cancel();
      }
    });
  }

  void stopForgotResendTimer() {
    _forgotTimer?.cancel();
  }

  @override
  Future<void> close() {
    _usernameLoginController.close();
    _passwordController.close();
    _emailController.close();
    _usernameSignupController.close();
    _usernameErrorLoginController.close();
    _passwordErrorController.close();
    _emailErrorController.close();
    _usernameErrorSignupController.close();
    _otpErrorController.close();
    _isCheckingUsernameController.close();
    _isUsernameAvailableController.close();
    _registrationOtpResendTimerController.close();
    _forgotOtpResendTimerController.close();
    _registrationTimer?.cancel();
    _forgotTimer?.cancel();
    _debounceTimer?.cancel();
    return super.close();
  }
}
