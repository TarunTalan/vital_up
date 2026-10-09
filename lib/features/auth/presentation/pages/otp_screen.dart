import 'package:flutter/material.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
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

  /// Kept for dispose, where looking up the widget tree isn't allowed.
  late final AuthCubit _authCubit = context.read<AuthCubit>();

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
    _authCubit.clearAllFields();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
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
    for (var c in _controllers) {
      c.text = '\u200B';
    }
    for (int i = 0; i < _otpLength; i++) {
      _isBoxFilled[i] = false;
    }
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
      cubit.setOtpError('Enter all 6 digits');
      _triggerShake();
      return;
    }

    if (widget.flow == 'signup') {
      cubit.verifyOTP(
        otp: otp,
        token: _currentToken,
        email: widget.email,
        onSuccess: () async {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: VitalUpLoader(),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          Navigator.of(context).pop(); // Close loader
          context.goNamed('health-onboarding');
        },
        onError: (_) => _triggerShake(),
      );
    } else {
      cubit.verifyForgotPassword(
        code: otp,
        token: _currentToken,
        onSuccess: (resetToken) {
          if (!mounted) return;
          context.push(
            Uri(
              path: '/reset-password',
              queryParameters: {'token': resetToken},
            ).toString(),
          );
        },
        onError: (_) => _triggerShake(),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final colors = context.colors;
    final v = context.vColors;

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

                    return ResponsiveCenter(
                        child: Column(
                          children: [
                            AuthHeader(
                              headerText: headerTitle,
                              onBackClick: () => context.goNamed('login'),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                        padding: context.pagePadding,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: context.h(AppDimens.space32)),

                                              // ── Description + email hint ──
                                              Center(
                                                child: RichText(
                                                  textAlign: TextAlign.center,
                                                  text: TextSpan(
                                                    style: context.text.bodyLarge?.copyWith(
                                                      color: colors.onSurface,
                                                    ),
                                                    children: [
                                                      TextSpan(text: '$description '),
                                                      TextSpan(
                                                        text: widget.email,
                                                        style: context.text.bodyLarge?.copyWith(
                                                          color: AppColors.primaryActive,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              SizedBox(height: context.h(AppDimens.space32)),

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

                                                      // Figma num input: default / active / filled / error.
                                                      final borderColor = showErrorBorder
                                                          ? colors.error
                                                          : isFocused
                                                              ? colors.primary
                                                              : v.glassBorder!;

                                                      final borderWidth =
                                                          showErrorBorder || isFocused
                                                              ? AppDimens.borderThick
                                                              : AppDimens.borderThin;

                                                      final boxColor = showErrorBorder
                                                          ? v.errorFill
                                                          : isFilled && !isFocused
                                                              ? v.primaryFill
                                                              : v.glassFill;

                                                      return Flexible(
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: AppDimens.space2,
                                                          ),
                                                          child: ConstrainedBox(
                                                            constraints: const BoxConstraints(
                                                              maxWidth: AppDimens.inputHeight,
                                                            ),
                                                            child: AspectRatio(
                                                              aspectRatio: 1,
                                                              child: AnimatedContainer(
                                                        duration: AppDurations.fast,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: borderColor,
                                                            width: borderWidth,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  AppDimens.radiusTab),
                                                          color: boxColor,
                                                          boxShadow: isFocused && !showErrorBorder
                                                              ? AppShadows.inputFocus
                                                              : null,
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
                                                          style: context.text.headlineMedium?.copyWith(
                                                            color: colors.onSurface,
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
                                                            enabledBorder: InputBorder.none,
                                                            focusedBorder: InputBorder.none,
                                                            disabledBorder: InputBorder.none,
                                                            filled: false,
                                                            isDense: true,
                                                            contentPadding:
                                                                EdgeInsets.zero,
                                                          ),
                                                        ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(height: AppDimens.space4),

                                              // ── Inline message area (min height to prevent shifting) ──
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  minHeight: AppDimens.space24,
                                                ),
                                                child: displayError != null
                                                    ? Text(
                                                        displayError,
                                                        style: context.text.bodyLarge?.copyWith(
                                                              color: (displayError.toLowerCase().contains('success') ||
                                                                      displayError.toLowerCase().contains('sent'))
                                                                  ? colors.primary
                                                                  : colors.error,
                                                            ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                              SizedBox(height: context.h(AppDimens.space24)),
                                              // ── Verify Button ──
                                              PrimaryAuthButton(
                                                label: buttonLabel,
                                                isLoading: isLoading && !_isResending,
                                                onTap: _isResending ? () {} : _verifyOtp,
                                              ),

                                              const SizedBox(height: AppDimens.buttonGap),

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

                                                  return SecondaryAuthButton(
                                                      enabled: isResendEnabled,
                                                      isLoading: _isResending,
                                                      disabledTextColor:
                                                          v.secondaryButtonText,
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
                                                               cubit.setOtpError('New code sent');
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
                                                              cubit.setOtpError('New code sent to your email');
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
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: AppDimens.space20),
                                            ],
                                          ),
                              ),
                            ),
                          ],
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
