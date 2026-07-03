import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_header.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String token;
  final String flow; // 'signup' or 'forgot'

  const OtpScreen({
    super.key,
    required this.email,
    required this.token,
    required this.flow,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final List<bool> _isBoxFilled = List.generate(_otpLength, (_) => false);

  String _currentToken = '';

  // Shake animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Tracks whether boxes should show error border
  bool _hasError = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token;

    _controllers =
        List.generate(_otpLength, (_) => TextEditingController(text: '\u200B'));
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());

    // Shake animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    // Start resend timer immediately
    final cubit = context.read<AuthCubit>();
    if (widget.flow == 'signup') {
      cubit.startRegistrationResendTimer();
    } else {
      cubit.startForgotResendTimer();
    }

    // Focus listener for border redraws
    for (int i = 0; i < _otpLength; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _controllers[i].selection =
              TextSelection.collapsed(offset: _controllers[i].text.length);
        }
        setState(() {});
      });
    }

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes[0].canRequestFocus) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    // Clear all fields and state in the Cubit when this screen is dismissed
    context.read<AuthCubit>().clearAllFields();
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _triggerShake() {
    setState(() => _hasError = true);
    _shakeController.forward(from: 0);
  }

  void _clearError() {
    if (_hasError) setState(() => _hasError = false);
    context.read<AuthCubit>().clearOtpError();
  }

  void _resetBoxes() {
    for (var c in _controllers) c.text = '\u200B';
    for (int i = 0; i < _otpLength; i++) _isBoxFilled[i] = false;
    setState(() => _hasError = false);
    FocusScope.of(context).unfocus();
  }

  void _handlePaste(String text, int startIndex) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '').split('');
    if (digits.isEmpty) return;

    for (int i = 0; i < digits.length && (startIndex + i) < _otpLength; i++) {
      _controllers[startIndex + i].text = digits[i];
      _isBoxFilled[startIndex + i] = true;
    }

    final target = (startIndex + digits.length).clamp(0, _otpLength - 1);
    _focusNodes[target].requestFocus();

    final otp =
        _controllers.map((c) => c.text.replaceAll('\u200B', '')).join();
    if (otp.length == _otpLength) _verifyOtp();
  }

  void _verifyOtp() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<AuthCubit>();
    final otp =
        _controllers.map((c) => c.text.replaceAll('\u200B', '')).join();

    if (otp.length < _otpLength) {
      cubit.setOtpError('Please fill in all 6 digits');
      _triggerShake();
      return;
    }

    if (widget.flow == 'signup') {
      cubit.verifyOTP(
        otp: otp,
        token: _currentToken,
        email: widget.email,
        onSuccess: () {
          if (!mounted) return;
          context.goNamed('dashboard');
        },
        onError: (_) => _triggerShake(),
      );
    } else {
      cubit.verifyForgotPassword(
        code: otp,
        token: _currentToken,
        onSuccess: (resetToken) {
          if (!mounted) return;
          context.push('/reset-password?token=$resetToken');
        },
        onError: (_) => _triggerShake(),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final colors = Theme.of(context).colorScheme;
    final customColors =
        Theme.of(context).extension<VitalUpColors>() ??
            AppTheme.lightCustomColors;

    final headerTitle = 'Verify OTP';
    final description = widget.flow == 'signup'
        ? 'Enter the 6-digit OTP sent to'
        : 'Enter the verification OTP sent to';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (MediaQuery.of(context).viewInsets.bottom > 0.0) {
          FocusScope.of(context).unfocus();
        } else {
          context.goNamed('login');
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AuthBackground(
            style: AuthBackgroundStyle.blobs,
            child: BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthError) {
                  // Unexpected server error — route inline and trigger shake
                  cubit.setOtpError(state.message);
                  _triggerShake();
                  cubit.reset();
                }
              },
              builder: (context, state) {
                final isLoading = state is AuthLoading;

                final otpText = _controllers.map((c) => c.text.replaceAll('\u200B', '')).join();
                final isOtpComplete = otpText.length == _otpLength;
                final buttonLabel = !isOtpComplete
                    ? 'Enter OTP'
                    : (widget.flow == 'signup'
                        ? 'Verify & Register'
                        : 'Verify & Reset Password');

                return StreamBuilder<String?>(
                  stream: cubit.otpErrorStream,
                  builder: (context, errorSnapshot) {
                    final displayError = errorSnapshot.data;
                    final isSuccessMessage = displayError != null &&
                        (displayError.toLowerCase().contains('success') ||
                         displayError.toLowerCase().contains('sent'));
                    final showErrorBorder = _hasError || (displayError != null && !isSuccessMessage);

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          children: [
                            AuthHeader(
                              headerText: headerTitle,
                              onBackClick: () => context.goNamed('login'),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: IntrinsicHeight(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: AppTheme.hPadding),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 20.0),
                      
                                              // ── Description + email hint ──
                                              Center(
                                                child: RichText(
                                                  textAlign: TextAlign.center,
                                                  text: TextSpan(
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: colors.onSurface
                                                              .withValues(alpha: 0.7),
                                                        ),
                                                    children: [
                                                      TextSpan(text: '$description '),
                                                      TextSpan(
                                                        text: widget.email,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color: colors.primary,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                      
                                              const SizedBox(height: 20.0),
                      
                                              // ── OTP Boxes with shake ──
                                              AnimatedBuilder(
                                                animation: _shakeAnimation,
                                                builder: (context, child) =>
                                                    Transform.translate(
                                                  offset:
                                                      Offset(_shakeAnimation.value, 0),
                                                  child: child,
                                                ),
                                                child: AutofillGroup(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.spaceBetween,
                                                    children:
                                                        List.generate(_otpLength, (index) {
                                                      final isFocused =
                                                          _focusNodes[index].hasFocus;
                                                      final isFilled =
                                                          _controllers[index]
                                                              .text
                                                              .replaceAll('\u200B', '')
                                                              .isNotEmpty;
                      
                                                      final borderColor = showErrorBorder
                                                          ? colors.error
                                                          : isFocused
                                                              ? colors.primary
                                                              : (customColors.inputBorder ??
                                                                  AppTheme.lightCustomColors
                                                                      .inputBorder!);
                      
                                                      final borderWidth =
                                                          showErrorBorder || isFocused
                                                              ? AppTheme.borderWidthFocused
                                                              : AppTheme.borderWidthDefault;
                      
                                                      final boxColor = showErrorBorder
                                                          ? colors.error
                                                              .withValues(alpha: 0.08)
                                                          : isFilled
                                                              ? colors.surfaceBright
                                                              : Colors.transparent;
                      
                                                      return AnimatedContainer(
                                                        duration: const Duration(
                                                            milliseconds: 150),
                                                        width: AppTheme.inputHeight,
                                                        height: AppTheme.inputHeight,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: borderColor,
                                                            width: borderWidth,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  AppTheme.inputRadius),
                                                          color: boxColor,
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: TextField(
                                                          controller: _controllers[index],
                                                          focusNode: _focusNodes[index],
                                                          keyboardType:
                                                              TextInputType.number,
                                                          textAlign: TextAlign.center,
                                                          maxLength: index == 0 ? 7 : 2,
                                                          enabled: !isLoading,
                                                          autofillHints: index == 0
                                                              ? const [AutofillHints.oneTimeCode]
                                                              : null,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .displayMedium
                                                              ?.copyWith(
                                                                color: showErrorBorder
                                                                    ? colors.error
                                                                    : colors.onSurface,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                          showCursor: true,
                                                          cursorColor: showErrorBorder
                                                              ? colors.error
                                                              : colors.primary,
                                                          onChanged: (val) {
                                                            final digitsOnly = val
                                                                .replaceAll('\u200B', '');
                      
                                                            // 1. Paste
                                                            if (digitsOnly.length > 1) {
                                                              _handlePaste(
                                                                  digitsOnly, index);
                                                              _clearError();
                                                              return;
                                                            }
                      
                                                            // 2. Backspace
                                                            if (val.isEmpty) {
                                                              _controllers[index].text =
                                                                  '\u200B';
                                                              _controllers[index]
                                                                  .selection = const TextSelection
                                                                  .collapsed(offset: 1);
                      
                                                              if (_isBoxFilled[index]) {
                                                                _isBoxFilled[index] = false;
                                                              } else if (index > 0) {
                                                                _focusNodes[index - 1]
                                                                    .requestFocus();
                                                                _controllers[index - 1]
                                                                    .text = '\u200B';
                                                                _controllers[index - 1]
                                                                        .selection =
                                                                    const TextSelection
                                                                        .collapsed(
                                                                        offset: 1);
                                                                _isBoxFilled[index - 1] =
                                                                    false;
                                                              }
                                                              _clearError();
                                                              setState(() {});
                                                              return;
                                                            }
                      
                                                            // 3. Normal typing
                                                            if (digitsOnly.isNotEmpty) {
                                                              final newChar =
                                                                  digitsOnly.substring(
                                                                      digitsOnly.length -
                                                                          1);
                                                              _controllers[index].text =
                                                                  newChar;
                                                              _controllers[index]
                                                                  .selection = const TextSelection
                                                                  .collapsed(offset: 1);
                                                              _isBoxFilled[index] = true;
                      
                                                              if (index < _otpLength - 1) {
                                                                _focusNodes[index + 1]
                                                                    .requestFocus();
                                                              } else {
                                                                final otp = _controllers
                                                                    .map((c) => c.text
                                                                        .replaceAll(
                                                                            '\u200B', ''))
                                                                    .join();
                                                                if (otp.length ==
                                                                    _otpLength) {
                                                                  _verifyOtp();
                                                                }
                                                              }
                                                            }
                                                            _clearError();
                                                            setState(() {});
                                                          },
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter
                                                                .allow(RegExp(
                                                                    r'[0-9\u200B]')),
                                                          ],
                                                          decoration:
                                                              const InputDecoration(
                                                            counterText: '',
                                                            border: InputBorder.none,
                                                            isDense: true,
                                                            contentPadding:
                                                                EdgeInsets.zero,
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ),
                      
                                              const SizedBox(height: 10),
                      
                                              // ── Inline Error Message Area (Fixed height to prevent shifting) ──
                                              SizedBox(
                                                height: 20.0,
                                                child: displayError != null
                                                    ? Text(
                                                        displayError,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: (displayError.toLowerCase().contains('success') ||
                                                                      displayError.toLowerCase().contains('sent'))
                                                                  ? colors.primary
                                                                  : colors.error,
                                                            ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                              const Spacer(),
                                              // ── Verify Button ──
                                              PrimaryAuthButton(
                                                label: buttonLabel,
                                                isLoading: isLoading && !_isResending,
                                                onTap: _isResending ? () {} : _verifyOtp,
                                              ),
                      
                                              const SizedBox(height: 20.0),
                      
                                              // ── Resend Button with 30s cooldown ──
                                              StreamBuilder<int>(
                                                stream: widget.flow == 'signup'
                                                    ? cubit.registrationOtpResendTimerStream
                                                    : cubit.forgotOtpResendTimerStream,
                                                initialData: widget.flow == 'signup'
                                                    ? cubit.registrationResendSecs
                                                    : cubit.forgotResendSecs,
                                                builder: (context, timerSnapshot) {
                                                  final secondsLeft =
                                                      timerSnapshot.data ?? 0;
                                                  final isResendEnabled =
                                                      secondsLeft <= 0 && !isLoading;
                      
                                                  return SizedBox(
                                                    width: double.infinity,
                                                    height: AppTheme.buttonHeight,
                                                    child: SecondaryAuthButton(
                                                      enabled: isResendEnabled,
                                                      isLoading: _isResending,
                                                      disabledTextColor:
                                                          const Color(0xFF0F7586),
                                                      onTap: () {
                                                        _resetBoxes();
                                                        cubit.clearOtpError();
                                                        setState(() => _isResending = true);
                      
                                                        if (widget.flow == 'signup') {
                                                           cubit.resendOTP(
                                                             token: _currentToken,
                                                             email: widget.email,
                                                             onSuccess: () {
                                                               if (!mounted) return;
                                                               setState(() => _isResending = false);
                                                               cubit.setOtpError('OTP resent successfully');
                                                             },
                                                             onError: (_) {
                                                               if (!mounted) return;
                                                               setState(() => _isResending = false);
                                                             },
                                                           );
                                                        } else {
                                                          cubit.resendForgotPassword(
                                                            currentToken: _currentToken,
                                                            onSuccess: (newToken) {
                                                              if (!mounted) return;
                                                              setState(() {
                                                                _currentToken = newToken;
                                                                _isResending = false;
                                                              });
                                                              cubit.setOtpError('New OTP sent to your email');
                                                            },
                                                            onError: (_) {
                                                              if (!mounted) return;
                                                              setState(() => _isResending = false);
                                                            },
                                                          );
                                                        }
                                                      },
                                                      label: isResendEnabled
                                                          ? 'Resend OTP'
                                                          : 'Resend OTP in ${secondsLeft}s',
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 20.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
