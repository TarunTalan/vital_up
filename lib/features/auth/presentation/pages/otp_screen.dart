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

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<FocusNode> _keyboardFocusNodes;

  String _currentToken = '';

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token;
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _keyboardFocusNodes = List.generate(_otpLength, (_) => FocusNode());

    // Automatically focus first box on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes[0].canRequestFocus) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var node in _keyboardFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handlePaste(String text, int startIndex) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '').split('');
    if (digits.isEmpty) return;

    for (int i = 0; i < digits.length && (startIndex + i) < _otpLength; i++) {
      _controllers[startIndex + i].text = digits[i];
    }

    final targetIndex = (startIndex + digits.length - 1).clamp(0, _otpLength - 1);
    _focusNodes[targetIndex].requestFocus();
  }

  void _verifyOtp() {
    final cubit = context.read<AuthCubit>();
    final otp = _controllers.map((c) => c.text).join();

    if (widget.flow == 'signup') {
      cubit.verifyOTP(
        otp: otp,
        token: _currentToken,
        email: widget.email,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account verified successfully! Welcome to VitalUp.'),
              backgroundColor: Colors.green,
            ),
          );
          context.goNamed('login');
        },
        onError: (_) {},
      );
    } else {
      cubit.verifyForgotPassword(
        code: otp,
        token: _currentToken,
        onSuccess: () {},
        onError: (_) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final colors = Theme.of(context).colorScheme;

    final headerTitle = widget.flow == 'signup' ? 'Verify Your Email' : 'Verify Code';
    final description = widget.flow == 'signup'
        ? 'Please enter the OTP sent to your email.'
        : 'Enter the verification code sent to your email';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed('login');
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
        body: AuthBackground(
          style: AuthBackgroundStyle.blobs,
          child: BlocConsumer<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthForgotPasswordOtpVerified) {
                // Redirect to Reset Password screen with reset token
                context.push('/reset-password?token=${state.token}');
              } else if (state is AuthError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: colors.error,
                  ),
                );
                cubit.reset();
              }
            },
            builder: (context, state) {
              final isLoading = state is AuthLoading;
      
              return StreamBuilder<bool>(
                stream: cubit.isOtpLockedStream,
                initialData: false,
                builder: (context, isLockedSnapshot) {
                  final isLocked = isLockedSnapshot.data ?? false;
      
                  return StreamBuilder<int>(
                    stream: cubit.freezeTimeRemainingStream,
                    initialData: 0,
                    builder: (context, freezeSnapshot) {
                      final freezeTime = freezeSnapshot.data ?? 0;
                      final freezeMessage = isLocked && freezeTime > 0
                          ? 'Too many failed attempts. Please wait ${freezeTime}s'
                          : null;
      
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
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(horizontal: AppTheme.hPadding),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 40),
                                      Text(
                                        description,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: colors.onSurface.withValues(alpha: 0.7),
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),
                                      // Code boxes row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: List.generate(_otpLength, (index) {
                                          return KeyboardListener(
                                            focusNode: _keyboardFocusNodes[index],
                                            onKeyEvent: (event) {
                                              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                                                if (_controllers[index].text.isEmpty && index > 0) {
                                                  _focusNodes[index - 1].requestFocus();
                                                  _controllers[index - 1].clear();
                                                  cubit.clearOtpError();
                                                }
                                              }
                                            },
                                            child: Container(
                                              // Figma OTP box: 52×52dp
                                              width: AppTheme.inputHeight,
                                              height: AppTheme.inputHeight,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: state is AuthError || freezeMessage != null
                                                      ? colors.error
                                                      : _focusNodes[index].hasFocus && !isLocked
                                                          ? colors.primary
                                                          : (Theme.of(context).extension<VitalUpColors>()?.inputBorder ?? AppTheme.lightCustomColors.inputBorder!),
                                                  width: _focusNodes[index].hasFocus && !isLocked
                                                      ? AppTheme.borderWidthFocused
                                                      : AppTheme.borderWidthDefault,
                                                ),
                                                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                                                color: state is AuthError || freezeMessage != null
                                                    ? colors.surface
                                                    : _controllers[index].text.isNotEmpty
                                                        ? colors.surfaceBright
                                                        : Colors.transparent,
                                              ),
                                              alignment: Alignment.center,
                                              child: TextField(
                                                controller: _controllers[index],
                                                focusNode: _focusNodes[index],
                                                keyboardType: TextInputType.number,
                                                textAlign: TextAlign.center,
                                                maxLength: index == 0 ? 6 : 1, // First text field allows pasting 6 digit code
                                                enabled: !isLocked && !isLoading,
                                                // Figma: 26sp w500 for OTP digit
                                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                                      color: colors.onSurface,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                showCursor: true,
                                                cursorColor: colors.primary,
                                                onChanged: (val) {
                                                  if (val.length > 1) {
                                                    _handlePaste(val, index);
                                                    cubit.clearOtpError();
                                                    return;
                                                  }
                                                  if (val.isNotEmpty && index < _otpLength - 1) {
                                                    _focusNodes[index + 1].requestFocus();
                                                  }
                                                  cubit.clearOtpError();
                                                  setState(() {});
                                                },
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                ],
                                                decoration: const InputDecoration(
                                                  counterText: '',
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 12),
                                      // Error Message Area
                                      StreamBuilder<String?>(
                                        stream: cubit.otpErrorStream,
                                        builder: (context, errorSnapshot) {
                                          final displayError = freezeMessage ?? errorSnapshot.data;
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              displayError ?? '',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: colors.error,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 32),
                                      // Verify Button
                                      PrimaryAuthButton(
                                        label: widget.flow == 'signup' ? 'Verify OTP' : 'Verify Code',
                                        isLoading: isLoading,
                                        enabled: !isLocked,
                                        onTap: _verifyOtp,
                                      ),
                                      const SizedBox(height: 12),
                                      // Resend Code Outlined Button with Timer
                                      StreamBuilder<int>(
                                        stream: widget.flow == 'signup'
                                            ? cubit.registrationOtpResendTimerStream
                                            : cubit.forgotOtpResendTimerStream,
                                        initialData: 30,
                                        builder: (context, timerSnapshot) {
                                          final secondsLeft = timerSnapshot.data ?? 0;
                                          final isResendEnabled = secondsLeft <= 0 && !isLocked && !isLoading;

                                          return SizedBox(
                                            width: double.infinity,
                                            height: AppTheme.buttonHeight,
                                            child: SecondaryAuthButton(
                                              enabled: isResendEnabled,
                                              onTap: () {
                                                for (var controller in _controllers) {
                                                  controller.clear();
                                                }
                                                _focusNodes[0].requestFocus();
                                                cubit.clearOtpError();

                                                if (widget.flow == 'signup') {
                                                  cubit.resendOTP(
                                                    token: _currentToken,
                                                    email: widget.email,
                                                    onSuccess: () {},
                                                    onError: (_) {},
                                                  );
                                                } else {
                                                  cubit.resendForgotPassword(
                                                    currentToken: _currentToken,
                                                    onSuccess: (newToken) {
                                                      setState(() {
                                                        _currentToken = newToken;
                                                      });
                                                    },
                                                    onError: (_) {},
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
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
