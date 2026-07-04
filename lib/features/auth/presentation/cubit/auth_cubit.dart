import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vital_up/features/auth/domain/entities/user_entity.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit({required this._authRepository})
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
  bool validateUsernameLogin() {
    final val = _usernameLogin.trim();
    if (val.isEmpty) {
      _usernameErrorLoginController.add('Username or Email is required');
      return false;
    }
    
    bool isFormatValid = true;
    if (val.contains('@')) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(val) || val.length > 254) {
        isFormatValid = false;
      }
    } else {
      final usernameRegex = RegExp(r'^[A-Za-z0-9._]+$');
      if (val.length < 3 || val.length > 20 || !usernameRegex.hasMatch(val)) {
        isFormatValid = false;
      }
    }

    if (!isFormatValid) {
      _usernameErrorLoginController.add('');
      _passwordErrorController.add('Invalid credentials.');
      return false;
    }

    _usernameErrorLoginController.add(null);
    return true;
  }

  bool validateUsernameSignup() {
    if (_usernameSignup.trim().isEmpty) {
      _usernameErrorSignupController.add('Username is required');
      return false;
    }
    if (_usernameSignup.length < 3) {
      _usernameErrorSignupController.add('Username must be at least 3 characters');
      return false;
    }
    if (_usernameSignup.length > 20) {
      _usernameErrorSignupController.add('Username must be at most 20 characters');
      return false;
    }
    final regex = RegExp(r'^[A-Za-z0-9._]+$');
    if (!regex.hasMatch(_usernameSignup)) {
      _usernameErrorSignupController.add('Username can only contain letters, numbers, dots, and underscores');
      return false;
    }
    _usernameErrorSignupController.add(null);
    return true;
  }

  bool validateEmail() {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (_email.trim().isEmpty) {
      _emailErrorController.add('Email is required');
      return false;
    }
    if (_email.length > 100) {
      _emailErrorController.add('Email must be at most 100 characters');
      return false;
    }
    if (!emailRegex.hasMatch(_email)) {
      _emailErrorController.add('Please enter a valid email');
      return false;
    }
    _emailErrorController.add(null);
    return true;
  }

  bool validatePassword() {
    if (_password.isEmpty) {
      _passwordErrorController.add('Password is required');
      return false;
    }
    final error = _getPasswordValidationError(_password);
    if (error != null) {
      _passwordErrorController.add(error);
      return false;
    }
    _passwordErrorController.add(null);
    return true;
  }

  bool validatePasswordForLogin() {
    if (_password.isEmpty) {
      _passwordErrorController.add('Password is required');
      return false;
    }
    if (_password.length < 8 || _password.length > 16) {
      _usernameErrorLoginController.add('');
      _passwordErrorController.add('Invalid credentials.');
      return false;
    }
    _passwordErrorController.add(null);
    return true;
  }

  String? _getPasswordValidationError(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
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

  String _sanitizeRawErrorMessage(String message) {
    // Extract nested message text if inside exception string formats
    // e.g. "AuthApiException(message: XYZ, statusCode: ...)"
    final messageRegExp = RegExp(r'(?:message:\s*|message\s*=\s*|message:\s*")([^",\)]+)');
    final match = messageRegExp.firstMatch(message);
    if (match != null) {
      return match.group(1)?.trim() ?? message;
    }
    return message;
  }

  // Auth Operations
  String _mapFailureToMessage(String originalMessage) {
    final origLower = originalMessage.toLowerCase();
    
    // Check network errors on the original raw message FIRST to give it absolute priority!
    if (origLower.contains('socketexception') || 
        origLower.contains('network') || 
        origLower.contains('connection') || 
        origLower.contains('handshake') || 
        origLower.contains('failed host lookup') ||
        origLower.contains('clientexception')) {
      return 'No internet connection. Please check your network.';
    }

    final cleanMsg = _sanitizeRawErrorMessage(originalMessage);
    final msg = cleanMsg.toLowerCase();

    if (msg.contains('cancelled') || msg.contains('canceled')) {
      return 'Google sign-in was cancelled.';
    }

    if (msg.contains('missing id token') || 
        msg.contains('missing_id_token') || 
        msg.contains('failed: missing')) {
      return 'Google authentication failed. Please try again.';
    }
    
    if (msg.contains('rate limit') || 
        msg.contains('too many requests') || 
        msg.contains('too_many_requests')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }

    if (msg.contains('security purposes') || msg.contains('request this after')) {
      final match = RegExp(r'\d+').firstMatch(cleanMsg);
      if (match != null) {
        final seconds = match.group(0);
        return 'Please wait ${seconds}s before requesting a new OTP.';
      }
      return 'Please wait before requesting a new OTP.';
    }
    
    if (msg.contains('invalid login credentials') || 
        msg.contains('invalid_credentials') ||
        msg.contains('username or password') ||
        msg.contains('no account exist') ||
        msg.contains('invalid username or password')) {
      return 'Invalid credentials.';
    }
    
    if (msg.contains('email not confirmed') || 
        msg.contains('email_not_confirmed')) {
      return 'Please verify your email address first.';
    }
    
    if (msg.contains('already exists') || 
        msg.contains('already registered') || 
        msg.contains('user already registered') ||
        msg.contains('email already in use') ||
        msg.contains('email already registered')) {
      return 'This email is already registered.';
    }

    if (msg.contains('not registered') || 
        msg.contains('please sign up') || 
        msg.contains('no user found')) {
      return 'Email is not registered. Please sign up.';
    }

    if (msg.contains('should be different from') ||
        msg.contains('different from the old') ||
        msg.contains('must be different') ||
        msg.contains('same as old')) {
      return 'New password must be different from your old password.';
    }
    
    if (msg.contains('password should be') || 
        msg.contains('weak password') ||
        msg.contains('password too short')) {
      return 'Password is too weak. Please check password requirements.';
    }
    
    if (msg.contains('token') ||
        msg.contains('otp') ||
        msg.contains('verification') ||
        msg.contains('confirmation') ||
        msg.contains('code') ||
        msg.contains('expired')) {
      return 'Invalid or expired OTP. Please check and try again.';
    }

    if (cleanMsg.isNotEmpty) {
      final hasTechnicalTerms = msg.contains('exception') || 
                                msg.contains('error') || 
                                msg.contains('database') || 
                                msg.contains('rls') || 
                                msg.contains('row-level') || 
                                msg.contains('postgres') || 
                                msg.contains('supabase') || 
                                msg.contains('null') || 
                                msg.contains('api') || 
                                msg.contains('sdk') ||
                                msg.contains('statuscode') ||
                                msg.contains('failed');
                                
      if (cleanMsg.length < 60 && !hasTechnicalTerms && !cleanMsg.contains('{') && !cleanMsg.contains('[')) {
        return cleanMsg;
      }
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> signIn({required Function() onSuccess}) async {
    if (!validateUsernameLogin() || !validatePasswordForLogin()) return;

    emit(AuthLoading());
    final result = await _authRepository.signIn(_usernameLogin, _password);

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        if (userFriendlyMessage.toLowerCase().contains('incorrect') ||
            userFriendlyMessage.toLowerCase().contains('credentials') ||
            userFriendlyMessage.toLowerCase().contains('username/email') ||
            userFriendlyMessage.toLowerCase().contains('password')) {
          // Highlight both fields in red, but display the text below the password field
          _usernameErrorLoginController.add('');
          _passwordErrorController.add('Invalid credentials.');
        } else if (userFriendlyMessage.contains('verify')) {
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
    // Guard: block if username availability check hasn't passed
    if (_isUsernameAvailable != true) {
      final msg = _lastUsernameError ?? 'Please wait for username check or choose an available username.';
      _usernameErrorSignupController.add(msg);
      onError(msg);
      return;
    }

    emit(AuthLoading());
    final result = await _authRepository.signUp(_usernameSignup, _email, _password);

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
    if (otp.length != 6) {
      const msg = 'Please enter all 6 digits';
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

    result.fold(
      (failure) {
        emit(AuthOtpSent(token: token, email: email));
        final key = email.trim().toLowerCase();
        _otpFailCounts[key] = (_otpFailCounts[key] ?? 0) + 1;
        final used = _otpFailCounts[key] ?? 1;
        final remaining = (_maxOtpAttempts - used).clamp(0, _maxOtpAttempts);

        final errorMsg = _mapFailureToMessage(failure.message);
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
            displayName: currentUser.userMetadata?['username'] ?? email.split('@')[0],
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

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
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
    if (!validateEmail()) return;

    emit(AuthLoading());
    final result = await _authRepository.requestForgotPassword(_email);

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        if (userFriendlyMessage.contains('not registered') || 
            userFriendlyMessage.contains('sign up')) {
          _emailErrorController.add(userFriendlyMessage);
          emit(AuthInitial());
        } else {
          emit(AuthError(userFriendlyMessage));
        }
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
    if (code.length != 6) {
      const msg = 'Please enter all 6 digits';
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

    result.fold(
      (failure) {
        emit(AuthForgotPasswordOtpSent(token: token, email: _email));
        final key = _email.trim().toLowerCase();
        _otpFailCounts[key] = (_otpFailCounts[key] ?? 0) + 1;
        final used = _otpFailCounts[key] ?? 1;
        final remaining = (_maxOtpAttempts - used).clamp(0, _maxOtpAttempts);

        final errorMsg = _mapFailureToMessage(failure.message);
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

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
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
    if (!validatePassword()) return;

    emit(AuthLoading());
    final result = await _authRepository.resetPassword(
      newPassword: _password,
      token: resetToken,
    );

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
    emit(AuthLoading());
    final result = await _authRepository.signInWithGoogle();

    result.fold(
      (failure) => emit(AuthError(_mapFailureToMessage(failure.message))),
      (user) {
        emit(AuthAuthenticated(user));
        onSuccess();
      },
    );
  }

  Future<void> checkSession() async {
    final active = await _authRepository.isSessionActive();
    active.fold(
      (_) => emit(AuthUnauthenticated()),
      (isActive) async {
        if (isActive) {
          final userResult = await _authRepository.getCurrentUser();
          userResult.fold(
            (_) => emit(AuthUnauthenticated()),
            (user) {
              if (user != null) {
                emit(AuthAuthenticated(user));
              } else {
                emit(AuthUnauthenticated());
              }
            },
          );
        } else {
          emit(AuthUnauthenticated());
        }
      },
    );
  }

  Future<void> logout() async {
    emit(AuthLoading());
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }

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
