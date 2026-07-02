import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final StreamController<String> _confirmPasswordController = StreamController<String>.broadcast();

  // Field Errors State Controllers
  final StreamController<String?> _usernameErrorLoginController = StreamController<String?>.broadcast();
  final StreamController<String?> _passwordErrorController = StreamController<String?>.broadcast();
  final StreamController<String?> _emailErrorController = StreamController<String?>.broadcast();
  final StreamController<String?> _usernameErrorSignupController = StreamController<String?>.broadcast();
  final StreamController<String?> _confirmPasswordErrorController = StreamController<String?>.broadcast();
  final StreamController<String?> _otpErrorController = StreamController<String?>.broadcast();

  // Checking state
  final StreamController<bool> _isCheckingUsernameController = StreamController<bool>.broadcast();
  final StreamController<bool?> _isUsernameAvailableController = StreamController<bool?>.broadcast();

  // Timers & Lockout State Controllers
  final StreamController<int> _registrationOtpResendTimerController = StreamController<int>.broadcast();
  final StreamController<int> _forgotOtpResendTimerController = StreamController<int>.broadcast();
  final StreamController<bool> _isOtpLockedController = StreamController<bool>.broadcast();
  final StreamController<int> _freezeTimeRemainingController = StreamController<int>.broadcast();

  // Current values cache
  String _usernameLogin = '';
  String _password = '';
  String _email = '';
  String _usernameSignup = '';
  String _confirmPassword = '';

  // Active timers & debounces
  Timer? _registrationTimer;
  Timer? _forgotTimer;
  Timer? _freezeTimer;
  Timer? _debounceTimer;

  // Lockout parameters
  bool _isOtpLocked = false;
  int _freezeTimeRemaining = 0;
  int _registrationResendSecs = 0;
  int _forgotResendSecs = 0;

  // Failure trackers
  final Map<String, int> _otpFailCounts = {};
  final Set<String> _frozenEmails = {};
  final Map<String, DateTime> _freezeTimestamps = {};

  static const int maxForgotOtpAttempts = 3;
  static const int freezeDurationSeconds = 5 * 60; // 5 minutes lockout

  // Getters for UI exposure
  String get usernameLoginVal => _usernameLogin;
  String get passwordVal => _password;
  String get emailVal => _email;
  String get usernameSignupVal => _usernameSignup;
  String get confirmPasswordVal => _confirmPassword;

  Stream<String> get usernameLoginStream => _usernameLoginController.stream;
  Stream<String> get passwordStream => _passwordController.stream;
  Stream<String> get emailStream => _emailController.stream;
  Stream<String> get usernameSignupStream => _usernameSignupController.stream;
  Stream<String> get confirmPasswordStream => _confirmPasswordController.stream;

  Stream<String?> get usernameErrorLoginStream => _usernameErrorLoginController.stream;
  Stream<String?> get passwordErrorStream => _passwordErrorController.stream;
  Stream<String?> get emailErrorStream => _emailErrorController.stream;
  Stream<String?> get usernameErrorSignupStream => _usernameErrorSignupController.stream;
  Stream<String?> get confirmPasswordErrorStream => _confirmPasswordErrorController.stream;
  Stream<String?> get otpErrorStream => _otpErrorController.stream;

  Stream<bool> get isCheckingUsernameStream => _isCheckingUsernameController.stream;
  Stream<bool?> get isUsernameAvailableStream => _isUsernameAvailableController.stream;

  Stream<int> get registrationOtpResendTimerStream => _registrationOtpResendTimerController.stream;
  Stream<int> get forgotOtpResendTimerStream => _forgotOtpResendTimerController.stream;
  Stream<bool> get isOtpLockedStream => _isOtpLockedController.stream;
  Stream<int> get freezeTimeRemainingStream => _freezeTimeRemainingController.stream;

  // Value change handlers
  void onUsernameLoginChange(String val) {
    _usernameLogin = val;
    _usernameLoginController.add(val);
    _usernameErrorLoginController.add(null);
  }

  void onPasswordChange(String val) {
    _password = val;
    _passwordController.add(val);
    _passwordErrorController.add(null);
  }

  void onEmailChange(String val) {
    _email = val;
    _emailController.add(val);
    _emailErrorController.add(null);
    _updateFreezeState();
  }

  void onUsernameSignupChange(String val) {
    _usernameSignup = val;
    _usernameSignupController.add(val);
    _usernameErrorSignupController.add(null);
    _isUsernameAvailableController.add(null);

    // Debounced username availability checks
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (validateUsernameSignup()) {
        _checkUsernameAvailability(val);
      }
    });
  }

  void onConfirmPasswordChange(String val) {
    _confirmPassword = val;
    _confirmPasswordController.add(val);
    _confirmPasswordErrorController.add(null);
  }

  // Validation functions matching AuthViewModel.kt
  bool validateUsernameLogin() {
    if (_usernameLogin.trim().isEmpty) {
      _usernameErrorLoginController.add('Username is required');
      return false;
    }
    if (_usernameLogin.length < 3 || _usernameLogin.length > 20) {
      _usernameErrorLoginController.add('Invalid username');
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

  bool validateConfirmPassword() {
    if (_confirmPassword.isEmpty) {
      _confirmPasswordErrorController.add('Please confirm your password');
      return false;
    }
    if (_confirmPassword != _password) {
      _confirmPasswordErrorController.add('Passwords do not match');
      return false;
    }
    _confirmPasswordErrorController.add(null);
    return true;
  }

  bool validatePasswordForLogin() {
    if (_password.isEmpty) {
      _passwordErrorController.add('Password is required');
      return false;
    }
    if (_password.length < 8 || _password.length > 16) {
      _passwordErrorController.add('Invalid password');
      return false;
    }
    _passwordErrorController.add(null);
    return true;
  }

  String? _getPasswordValidationError(String password) {
    if (password.length < 8 || password.length > 16) {
      return 'Password must be between 8 and 16 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one digit';
    }
    // Special character matching any printable non-alphanumeric character
    if (!password.contains(RegExp(r'[^\w\s]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  void clearErrorsOnly() {
    _usernameErrorLoginController.add(null);
    _passwordErrorController.add(null);
    _emailErrorController.add(null);
    _usernameErrorSignupController.add(null);
    _confirmPasswordErrorController.add(null);
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
    _confirmPassword = '';
    _passwordController.add('');
    _confirmPasswordController.add('');
    clearErrorsOnly();
  }

  // Username availability check remote call
  Future<void> _checkUsernameAvailability(String username) async {
    _isCheckingUsernameController.add(true);
    _usernameErrorSignupController.add(null);

    final result = await _authRepository.checkUsernameAvailability(username);
    result.fold(
      (failure) {
        if (_usernameSignup == username) {
          _usernameErrorSignupController.add(failure.message);
          _isUsernameAvailableController.add(false);
        }
      },
      (successMessage) {
        if (_usernameSignup == username) {
          _isUsernameAvailableController.add(true);
          _usernameErrorSignupController.add(successMessage);
        }
      },
    );
    _isCheckingUsernameController.add(false);
  }

  // Auth Operations
  String _mapFailureToMessage(String originalMessage) {
    final msg = originalMessage.toLowerCase();
    
    if (msg.contains('socketexception') || 
        msg.contains('network') || 
        msg.contains('connection') || 
        msg.contains('handshake') || 
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
      return 'No internet connection. Please check your network.';
    }
    
    if (msg.contains('rate limit') || 
        msg.contains('too many requests') || 
        msg.contains('too_many_requests')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }
    
    if (msg.contains('invalid login credentials') || 
        msg.contains('invalid_credentials') ||
        msg.contains('username or password') ||
        msg.contains('no account exist') ||
        msg.contains('invalid username or password')) {
      return 'Incorrect username/email or password.';
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
    
    if (msg.contains('password should be') || 
        msg.contains('weak password') ||
        msg.contains('password too short')) {
      return 'Password is too weak. Please check password requirements.';
    }
    
    if (msg.contains('invalid token') || 
        msg.contains('invalid otp') ||
        msg.contains('otp_expired') ||
        msg.contains('expired token') ||
        msg.contains('token expired') ||
        msg.contains('otp has expired') ||
        msg.contains('incorrect verification code') ||
        msg.contains('invalid confirmation code')) {
      if (msg.contains('expired')) {
        return 'The verification code has expired. Please request a new one.';
      }
      return 'Incorrect verification code. Please check and try again.';
    }

    if (originalMessage.isNotEmpty) {
      if (originalMessage.length < 60 && !originalMessage.contains('{') && !originalMessage.contains('[')) {
        return originalMessage;
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
        if (userFriendlyMessage.contains('username/email') || userFriendlyMessage.contains('password')) {
          _passwordErrorController.add(userFriendlyMessage);
        } else if (userFriendlyMessage.contains('verify')) {
          _usernameErrorLoginController.add(userFriendlyMessage);
        } else {
          _passwordErrorController.add(userFriendlyMessage);
        }
        emit(AuthError(userFriendlyMessage));
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
    final emailVal = _email.trim().toLowerCase();
    if (_isEmailFrozen(emailVal)) {
      const msg = 'Registration temporarily disabled for this email. Try again later';
      _emailErrorController.add(msg);
      onError(msg);
      return;
    }

    emit(AuthLoading());
    final result = await _authRepository.signUp(_usernameSignup, _email, _password);

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        
        if (userFriendlyMessage.contains('already registered') || userFriendlyMessage.contains('email')) {
          _emailErrorController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        } else if (failure.message.toLowerCase().contains('username')) {
          _usernameErrorSignupController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        } else {
          _emailErrorController.add(userFriendlyMessage);
          onError(userFriendlyMessage);
        }
        emit(AuthError(userFriendlyMessage));
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
    final emailVal = email.trim().toLowerCase();
    if (_isEmailFrozen(emailVal)) {
      const msg = 'Registration disabled. Try again later';
      _otpErrorController.add(msg);
      onError(msg);
      return;
    }

    if (otp.length != 6) {
      onError('Please enter complete 6 digit OTP');
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
        _incrementOtpFail(emailVal);

        final remaining = maxForgotOtpAttempts - (_otpFailCounts[emailVal] ?? 0);
        String attemptsMessage;
        
        if (remaining > 0) {
          final errorMsg = _mapFailureToMessage(failure.message);
          if (errorMsg.contains('expired')) {
            attemptsMessage = '$errorMsg ($remaining attempts left)';
          } else {
            attemptsMessage = 'Incorrect code. ($remaining attempts left)';
          }
        } else {
          attemptsMessage = 'Registration disabled. Try again in 5:00';
          _isOtpLocked = true;
          _isOtpLockedController.add(true);
          _startFreezeTimer(emailVal);
        }

        _otpErrorController.add(attemptsMessage);
        onError(attemptsMessage);
      },
      (_) {
        _resetOtpFail(emailVal);
        emit(AuthOtpVerified());
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
    final emailVal = email.trim().toLowerCase();
    _resetOtpFail(emailVal);
    _isOtpLocked = false;
    _isOtpLockedController.add(false);

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

  Future<void> requestForgotPassword({required Function() onSuccess}) async {
    if (!validateEmail()) return;

    final emailVal = _email.trim().toLowerCase();
    if (_isEmailFrozen(emailVal)) {
      emit(AuthError('Too many failed attempts. Forgot password is temporarily disabled for this email.'));
      return;
    }

    emit(AuthLoading());
    final result = await _authRepository.requestForgotPassword(_email);

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        emit(AuthError(userFriendlyMessage));
      },
      (token) {
        emit(AuthForgotPasswordOtpSent(token: token, email: _email));
        onSuccess();
        startForgotResendTimer();
      },
    );
  }

  Future<void> verifyForgotPassword({
    required String code,
    required Function() onSuccess,
    required Function(String err) onError,
    required String token,
  }) async {
    final emailVal = _email.trim().toLowerCase();
    if (_isEmailFrozen(emailVal)) {
      const msg = 'Too many failed attempts. Try again later.';
      _passwordErrorController.add(msg);
      onError(msg);
      return;
    }

    if (code.length != 6) {
      _passwordErrorController.add('Please enter a valid 6-digit OTP');
      onError('Please enter a valid 6-digit OTP');
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
        _incrementOtpFail(emailVal);

        final remaining = maxForgotOtpAttempts - (_otpFailCounts[emailVal] ?? 0);
        String attemptsMessage;
        
        if (remaining > 0) {
          final errorMsg = _mapFailureToMessage(failure.message);
          if (errorMsg.contains('expired')) {
            attemptsMessage = '$errorMsg ($remaining attempts left)';
          } else {
            attemptsMessage = 'Incorrect code. ($remaining attempts left)';
          }
        } else {
          attemptsMessage = 'Too many failed attempts. Please try again later.';
          _isOtpLocked = true;
          _isOtpLockedController.add(true);
          _startFreezeTimer(emailVal);
        }

        _passwordErrorController.add(attemptsMessage);
        onError(attemptsMessage);
      },
      (resetToken) {
        _resetOtpFail(emailVal);
        emit(AuthForgotPasswordOtpVerified(token: resetToken, email: _email));
        stopForgotResendTimer();
        onSuccess();
      },
    );
  }

  Future<void> resendForgotPassword({
    required Function(String token) onSuccess,
    required Function(String err) onError,
    required String currentToken,
  }) async {
    final emailVal = _email.trim().toLowerCase();
    if (_isEmailFrozen(emailVal)) {
      const msg = 'Forgot password is temporarily disabled for this email.';
      _emailErrorController.add(msg);
      onError(msg);
      return;
    }

    emit(AuthLoading());
    final result = await _authRepository.resendForgotPasswordOTP(
      email: _email,
      token: currentToken,
    );

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        emit(AuthForgotPasswordOtpSent(token: currentToken, email: _email));
        _passwordErrorController.add(userFriendlyMessage);
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
    if (!validatePassword() || !validateConfirmPassword()) return;

    emit(AuthLoading());
    final result = await _authRepository.resetPassword(
      newPassword: _password,
      token: resetToken,
    );

    result.fold(
      (failure) {
        final userFriendlyMessage = _mapFailureToMessage(failure.message);
        emit(AuthError(userFriendlyMessage));
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
      (failure) => emit(AuthError(failure.message)),
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

  // Failure tracking helpers matching AuthViewModel.kt
  bool _isEmailFrozen(String email) {
    final key = email.toLowerCase();
    if (!_frozenEmails.contains(key)) return false;

    final freezeTime = _freezeTimestamps[key];
    if (freezeTime == null) return false;

    final elapsed = DateTime.now().difference(freezeTime).inSeconds;
    if (elapsed >= freezeDurationSeconds) {
      _frozenEmails.remove(key);
      _freezeTimestamps.remove(key);
      _otpFailCounts.remove(key);
      _updateFreezeState();
      return false;
    }
    return true;
  }

  void _incrementOtpFail(String email) {
    final key = email.toLowerCase();
    _otpFailCounts[key] = (_otpFailCounts[key] ?? 0) + 1;

    if ((_otpFailCounts[key] ?? 0) >= maxForgotOtpAttempts) {
      _frozenEmails.add(key);
      _freezeTimestamps[key] = DateTime.now();
      _isOtpLocked = true;
      _isOtpLockedController.add(true);
      _startFreezeTimer(key);
    }
    _updateFreezeState();
  }

  void _resetOtpFail(String email) {
    final key = email.toLowerCase();
    _otpFailCounts.remove(key);
    _frozenEmails.remove(key);
    _freezeTimestamps.remove(key);
    _isOtpLocked = false;
    _isOtpLockedController.add(false);
    _freezeTimer?.cancel();
    _updateFreezeState();
  }

  void _updateFreezeState() {
    final emailVal = _email.trim().toLowerCase();
    _isOtpLocked = _isEmailFrozen(emailVal);
    _isOtpLockedController.add(_isOtpLocked);
  }

  void _startFreezeTimer(String email) {
    _freezeTimer?.cancel();
    _freezeTimeRemaining = freezeDurationSeconds;
    _freezeTimeRemainingController.add(_freezeTimeRemaining);

    _freezeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final key = email.toLowerCase();
      if (_isEmailFrozen(key)) {
        final freezeTime = _freezeTimestamps[key];
        if (freezeTime != null) {
          final elapsed = DateTime.now().difference(freezeTime).inSeconds;
          final remaining = (freezeDurationSeconds - elapsed).clamp(0, freezeDurationSeconds);
          _freezeTimeRemaining = remaining;
          _freezeTimeRemainingController.add(remaining);

          if (remaining <= 0) {
            _resetOtpFail(key);
            timer.cancel();
          }
        }
      } else {
        _resetOtpFail(key);
        timer.cancel();
      }
    });
  }

  // Timer Management helpers
  void startRegistrationResendTimer() {
    _registrationTimer?.cancel();
    _registrationResendSecs = 30;
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
    _forgotResendSecs = 30;
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
    _confirmPasswordController.close();
    _usernameErrorLoginController.close();
    _passwordErrorController.close();
    _emailErrorController.close();
    _usernameErrorSignupController.close();
    _confirmPasswordErrorController.close();
    _otpErrorController.close();
    _isCheckingUsernameController.close();
    _isUsernameAvailableController.close();
    _registrationOtpResendTimerController.close();
    _forgotOtpResendTimerController.close();
    _isOtpLockedController.close();
    _freezeTimeRemainingController.close();
    _registrationTimer?.cancel();
    _forgotTimer?.cancel();
    _freezeTimer?.cancel();
    _debounceTimer?.cancel();
    return super.close();
  }
}
